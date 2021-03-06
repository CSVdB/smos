{-# LANGUAGE LambdaCase #-}

{-
 - Cheatsheet:
 -
 - modifyMXXXM :: (Maybe X -> Maybe X) -> SmosM ()         -- Modify a Maybe field in SmosM
 - modifyMXXXSM :: (Maybe X -> SmosM (Maybe X)) -> SmosM () -- Modify a Maybe field in SmosM
 - modifyXXXM :: (X -> Maybe X) -> SmosM ()           -- Modify purely, don't do anything if 'Nothing'
 - modifyXXXD :: (X -> DeleteOrUpdate X) -> SmosM ()  -- Modify purely, possibly delete
 - modifyXXX :: (X -> X) -> SmosM ()                  -- Modify purely
 - modifyXXXS :: (X -> S X) -> SmosM ()               -- Modify in SmosM
 -}
module Smos.Actions.Utils
    ( module Smos.Actions.Utils
    , module Smos.Cursor.Editor
    , module Smos.Cursor.Entry
    , module Smos.Cursor.Header
    , module Smos.Cursor.SmosFile
    , module Smos.Cursor.StateHistory
    ) where

import Data.Maybe
import Data.Time

import Cursor.Types

import Smos.Data

import Smos.Cursor.Editor
import Smos.Cursor.Entry
import Smos.Cursor.Header
import Smos.Cursor.SmosFile
import Smos.Cursor.StateHistory

import Lens.Micro

import Smos.Types

modifyHeaderCursorWhenSelectedM ::
       (HeaderCursor -> Maybe HeaderCursor) -> SmosM ()
modifyHeaderCursorWhenSelectedM func =
    modifyHeaderCursorWhenSelected $ \hc -> fromMaybe hc $ func hc

modifyHeaderCursorWhenSelected :: (HeaderCursor -> HeaderCursor) -> SmosM ()
modifyHeaderCursorWhenSelected func =
    modifyEntryCursor $ \ec ->
        case entryCursorSelected ec of
            HeaderSelected -> ec & entryCursorHeaderCursorL %~ func
            _ -> ec

modifyMTodoStateM :: (Maybe TodoState -> Maybe TodoState) -> SmosM ()
modifyMTodoStateM func =
    modifyMStateHistoryCursorSM $ \mshc -> do
        now <- liftIO getCurrentTime
        pure $ Just $ stateHistoryCursorModTodoState now func mshc

modifyMStateHistoryCursorSM ::
       (Maybe StateHistoryCursor -> SmosM (Maybe StateHistoryCursor))
    -> SmosM ()
modifyMStateHistoryCursorSM func =
    modifyEntryCursorS $ entryCursorStateHistoryCursorL func

modifyEntryCursor :: (EntryCursor -> EntryCursor) -> SmosM ()
modifyEntryCursor func = modifyEntryCursorS $ pure . func

modifyEntryCursorS :: (EntryCursor -> SmosM EntryCursor) -> SmosM ()
modifyEntryCursorS func = modifyFileCursorS $ smosFileCursorSelectedEntryL func

modifyEmptyFile :: SmosFileCursor -> SmosM ()
modifyEmptyFile = modifyEmptyFileS . pure

modifyEmptyFileS :: SmosM SmosFileCursor -> SmosM ()
modifyEmptyFileS func =
    modifyMFileCursorS $ \case
        Nothing -> Just <$> func
        _ -> pure Nothing

modifyFileCursorM :: (SmosFileCursor -> Maybe SmosFileCursor) -> SmosM ()
modifyFileCursorM func = modifyFileCursor $ \sfc -> fromMaybe sfc $ func sfc

modifyFileCursor :: (SmosFileCursor -> SmosFileCursor) -> SmosM ()
modifyFileCursor func = modifyMFileCursor $ Just . func

modifyFileCursorS :: (SmosFileCursor -> SmosM SmosFileCursor) -> SmosM ()
modifyFileCursorS func =
    modifyMFileCursorS $ \mc ->
        case mc of
            Nothing -> pure Nothing
            Just c -> Just <$> func c

modifyMFileCursor :: (SmosFileCursor -> Maybe SmosFileCursor) -> SmosM ()
modifyMFileCursor func =
    modifyMFileCursorM $ \case
        Nothing -> Nothing
        Just sfc -> func sfc

modifyFileCursorD ::
       (SmosFileCursor -> DeleteOrUpdate SmosFileCursor) -> SmosM ()
modifyFileCursorD func =
    modifyMFileCursorM $ \msfc -> do
        sfc <- msfc
        case func sfc of
            Deleted -> Nothing
            Updated sfc' -> pure sfc'

modifyMFileCursorM :: (Maybe SmosFileCursor -> Maybe SmosFileCursor) -> SmosM ()
modifyMFileCursorM func = modifyMFileCursorS $ pure . func

modifyMFileCursorS ::
       (Maybe SmosFileCursor -> SmosM (Maybe SmosFileCursor)) -> SmosM ()
modifyMFileCursorS func = modifyEditorCursorS $ editorCursorSmosFileCursorL func

modifyEditorCursorM :: (EditorCursor -> Maybe EditorCursor) -> SmosM ()
modifyEditorCursorM func = modifyEditorCursor $ \ec -> fromMaybe ec $ func ec

modifyEditorCursor :: (EditorCursor -> EditorCursor) -> SmosM ()
modifyEditorCursor func = modifyEditorCursorS $ pure . func

modifyEditorCursorS :: (EditorCursor -> SmosM EditorCursor) -> SmosM ()
modifyEditorCursorS func = do
    ss <- get
    let msc = smosStateCursor ss
    msc' <- func msc
    let ss' = ss {smosStateCursor = msc'}
    put ss'
