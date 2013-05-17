module Database.Relational.Query.Projection (
  Projection, toMaybe,

  width,

  columns,

  unsafeFromColumns,

  compose, fromQualifiedSubQuery,

  pi, piMaybe, flattenMaybe
  ) where

import Prelude hiding ((!!), pi)

import Data.Array (Array, listArray)
import qualified Data.Array as Array

import Database.Record
  (PersistableWidth, persistableWidth, PersistableRecordWidth)
import Database.Record.Persistable (runPersistableRecordWidth)

import Database.Relational.Query.Pi (Pi)
import qualified Database.Relational.Query.Pi as Pi
import Database.Relational.Query.AliasId (Qualified)
import Database.Relational.Query.Sub (SubQuery, queryWidth)
import qualified Database.Relational.Query.Sub as SubQuery


data ProjectionUnit = Columns (Array Int String)
                    | Sub (Qualified SubQuery)

data Projection t = Composed [ProjectionUnit]

toMaybe :: Projection r -> Projection (Maybe r)
toMaybe =  d  where
  d (Composed qs) = Composed qs

widthOfUnit :: ProjectionUnit -> Int
widthOfUnit =  d  where
  d (Columns a) = mx - mn + 1 where (mn, mx) = Array.bounds a
  d (Sub sq)    = queryWidth sq

columnOfUnit :: ProjectionUnit -> Int -> String
columnOfUnit =  d  where
  d (Columns a) i | mn <= i && i <= mx = a Array.! i
                  | otherwise          = error $ "index out of bounds (unit): " ++ show i
    where (mn, mx) = Array.bounds a
  d (Sub sq) i = SubQuery.column sq i

width :: Projection r -> Int
width =  d  where
  d (Composed prod) = sum . map widthOfUnit $ prod

column :: Projection r -> Int -> String
column =  d  where
  d (Composed us') i' = rec us' i'  where
    rec []       _       = error $ "index out of bounds: " ++ show i'
    rec (u : us) i
      | i < widthOfUnit u = columnOfUnit u i
      | i < 0             = error $ "index out of bounds: " ++ show i
      | otherwise         = rec us (i - widthOfUnit u)

columns :: Projection r -> [String]
columns p = map (\n -> column p n) . take w $ [0 .. ]
  where w = width p


unsafeFromUnit :: ProjectionUnit -> Projection t
unsafeFromUnit =  Composed . (:[])

unsafeFromColumns :: [String] -> Projection t
unsafeFromColumns fs = unsafeFromUnit . Columns $ listArray (0, length fs - 1) fs

compose :: Projection a -> Projection b -> Projection (c a b)
compose (Composed a) (Composed b) = Composed $ a ++ b

fromQualifiedSubQuery :: Qualified SubQuery -> Projection t
fromQualifiedSubQuery =  unsafeFromUnit . Sub


unsafeProject :: PersistableRecordWidth b -> Projection a' -> Pi a b -> Projection b'
unsafeProject pr p pi' =
  unsafeFromColumns
  . take (runPersistableRecordWidth pr) . drop (Pi.leafIndex pi')
  . columns $ p

pi :: PersistableWidth b => Projection a -> Pi a b -> Projection b
pi =  unsafeProject persistableWidth

flattenMaybe :: Projection (Maybe (Maybe a)) -> Projection (Maybe a)
flattenMaybe (Composed pus) = Composed pus

piMaybe :: PersistableWidth b => Projection (Maybe a) -> Pi a b -> Projection (Maybe b)
piMaybe =  unsafeProject persistableWidth
