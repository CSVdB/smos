{-# OPTIONS_GHC -fno-warn-orphans #-}

module Smos.Cursor.Logbook.Gen where

import Data.GenValidity

import Smos.Data.Gen ()

import Cursor.Simple.List.NonEmpty.Gen ()

import Smos.Cursor.Logbook

instance GenUnchecked LogbookCursor

instance GenValid LogbookCursor where
    genValid = genValidStructurally
