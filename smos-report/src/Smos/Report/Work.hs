{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Smos.Report.Work where

import GHC.Generics (Generic)

import qualified Data.Map as M
import Data.Map (Map)
import Data.Time
import Data.Validity
import Data.Validity.Path ()

import Cursor.Simple.Forest

import Smos.Data

import Smos.Report.Agenda
import Smos.Report.Config
import Smos.Report.Filter
import Smos.Report.Path
import Smos.Report.Streaming

data WorkReport =
  WorkReport
    { workReportResultEntries :: [(RootedPath, Entry)]
    , workReportEntriesWithoutContext :: [(RootedPath, Entry)]
    , workReportAgendaEntries :: [AgendaEntry]
    }
  deriving (Show, Eq, Generic)

instance Validity WorkReport

instance Semigroup WorkReport where
  wr1 <> wr2 =
    WorkReport
      { workReportResultEntries = workReportResultEntries wr1 <> workReportResultEntries wr2
      , workReportEntriesWithoutContext =
          workReportEntriesWithoutContext wr1 <> workReportEntriesWithoutContext wr2
      , workReportAgendaEntries = workReportAgendaEntries wr1 <> workReportAgendaEntries wr2
      }

instance Monoid WorkReport where
  mempty =
    WorkReport
      { workReportResultEntries = mempty
      , workReportEntriesWithoutContext = mempty
      , workReportAgendaEntries = []
      }

data WorkReportContext =
  WorkReportContext
    { workReportContextNow :: ZonedTime
    , workReportContextBaseFilter :: Maybe Filter
    , workReportContextCurrentContext :: Filter
    , workReportContextAdditionalFilter :: Maybe Filter
    , workReportContextContexts :: Map ContextName Filter
    }
  deriving (Show, Generic)

makeWorkReport :: WorkReportContext -> RootedPath -> ForestCursor Entry -> WorkReport
makeWorkReport WorkReportContext {..} rp fc =
  let cur = forestCursorCurrent fc
      match b =
        if b
          then [(rp, cur)]
          else []
      combineFilter f mf = maybe f (FilterAnd f) mf
      filterWithBase f = combineFilter f workReportContextBaseFilter
      currentFilter =
        filterWithBase $
        combineFilter workReportContextCurrentContext workReportContextAdditionalFilter
      matchesSelectedContext = filterPredicate currentFilter rp fc
      matchesNoContext =
        not $ any (\f -> filterPredicate f rp fc) $ M.elems workReportContextContexts
   in WorkReport
        { workReportResultEntries = match matchesSelectedContext
        , workReportEntriesWithoutContext =
            match $
            maybe True (\f -> filterPredicate f rp fc) workReportContextBaseFilter &&
            matchesNoContext
        , workReportAgendaEntries =
            let go ae =
                  let day =
                        timestampDay (agendaEntryTimestamp ae)
                      today =
                          localDay (zonedTimeToLocalTime workReportContextNow)
                  in case agendaEntryTimestampName ae of
                    "SCHEDULED" -> day <=today
                    "DEADLINE" ->
                      day  <=
                        addDays 7 today
                    _ -> day == today
             in filter go $ makeAgendaEntry rp cur
        }
