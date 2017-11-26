-- |
-- Module      : Database.Relational.Query.Internal.BaseSQL
-- Copyright   : 2013-2017 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module provides base structure of SQL syntax tree.
module Database.Relational.Query.Internal.BaseSQL (
  Duplication (..), showsDuplication,
  Order (..), Nulls (..), OrderColumn, OrderingTerm, composeOrderBy,
  AssignColumn, AssignTerm, Assignment, composeSets,
  composeChunkValues, composeChunkValuesWithColumns,
  ) where

import Data.Monoid (Monoid (..), (<>))

import Language.SQL.Keyword (Keyword(..), (|*|), (.=.))
import qualified Language.SQL.Keyword as SQL

import Database.Relational.Query.Internal.SQL
  (StringSQL, rowConsStringSQL)


-- | Result record duplication attribute
data Duplication = All | Distinct  deriving Show

-- | Compose duplication attribute string.
showsDuplication :: Duplication -> StringSQL
showsDuplication =  dup  where
  dup All      = ALL
  dup Distinct = DISTINCT


-- | Order direction. Ascendant or Descendant.
data Order = Asc | Desc  deriving Show

-- | Order of null.
data Nulls =  NullsFirst | NullsLast deriving Show

-- | Type for order-by column
type OrderColumn = StringSQL

-- | Type for order-by term
type OrderingTerm = ((Order, Maybe Nulls), OrderColumn)

-- | Compose ORDER BY clause from OrderingTerms
composeOrderBy :: [OrderingTerm] -> StringSQL
composeOrderBy =  d where
  d []       = mempty
  d ts@(_:_) = ORDER <> BY <> SQL.fold (|*|) (map showsOt ts)
  showsOt ((o, mn), e) = e <> order o <> maybe mempty ((NULLS <>) . nulls) mn
  order Asc  = ASC
  order Desc = DESC
  nulls NullsFirst = FIRST
  nulls NullsLast  = LAST

-- | Column SQL String of assignment
type AssignColumn = StringSQL

-- | Value SQL String of assignment
type AssignTerm   = StringSQL

-- | Assignment pair
type Assignment = (AssignColumn, AssignTerm)

-- | Compose SET clause from ['Assignment'].
composeSets :: [Assignment] -> StringSQL
composeSets as = assigns  where
  assignList = foldr (\ (col, term) r ->
                       (col .=. term) : r)
               [] as
  assigns | null assignList = error "Update assignment list is null!"
          | otherwise       = SET <> SQL.fold (|*|) assignList

-- | Compose VALUES clause from value expression list.
composeChunkValues :: Int         -- ^ record count per chunk
                   -> [StringSQL] -- ^ value expression list
                   -> Keyword
composeChunkValues n0 vs =
    VALUES <> cvs
  where
    n | n0 >= 1    =  n0
      | otherwise  =  error $ "Invalid record count value: " ++ show n0
    cvs = SQL.fold (|*|) . replicate n $ rowConsStringSQL vs

-- | Compose VALUES clause from value expression list.
composeChunkValuesWithColumns :: Int          -- ^ record count per chunk
                              -> [Assignment] -- ^
                              -> StringSQL
composeChunkValuesWithColumns sz as =
    rowConsStringSQL cs <> composeChunkValues sz vs
  where
    (cs, vs) = unzip as