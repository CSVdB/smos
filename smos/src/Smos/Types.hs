{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Smos.Types
    ( SmosConfig(..)
    , KeyMap(..)
    , KeyMappings
    , KeyMapping(..)
    , Action(..)
    , action
    , ActionUsing(..)
    , actionUsing
    , AnyAction(..)
    , SmosEvent
    , SmosM
    , runSmosM
    , SmosState(..)
    , KeyPress(..)
    , DebugInfo(..)
    , ActivationDebug(..)
    , Priority(..)
    , Precedence(..)
    , ResourceName
    , MStop(..)
    , stop
    , module Control.Monad.Reader
    , module Control.Monad.State
    ) where

import Import

import Control.Monad.Reader
import Control.Monad.State

import Graphics.Vty.Input.Events as Vty

import Brick.Types as B hiding (Next)

import Smos.Cursor.Editor

data SmosConfig = SmosConfig
    { configKeyMap :: KeyMap
    } deriving (Generic)

data KeyMap = KeyMap
    { keyMapHelpMatchers :: KeyMappings
    , keyMapEmptyMatchers :: KeyMappings
    , keyMapEntryMatchers :: KeyMappings
    , keyMapHeaderMatchers :: KeyMappings
    , keyMapContentsMatchers :: KeyMappings
    , keyMapTimestampsMatchers :: KeyMappings
    , keyMapPropertiesMatchers :: KeyMappings
    , keyMapStateHistoryMatchers :: KeyMappings
    , keyMapTagsMatchers :: KeyMappings
    , keyMapLogbookMatchers :: KeyMappings
    , keyMapAnyMatchers :: KeyMappings
    } deriving (Generic)

instance Semigroup KeyMap where
    (<>) km1 km2 =
        KeyMap
        { keyMapHelpMatchers = keyMapHelpMatchers km1 <> keyMapHelpMatchers km2
        , keyMapEmptyMatchers =
              keyMapEmptyMatchers km1 <> keyMapEmptyMatchers km2
        , keyMapEntryMatchers =
              keyMapEntryMatchers km1 <> keyMapEntryMatchers km2
        , keyMapHeaderMatchers =
              keyMapHeaderMatchers km1 <> keyMapHeaderMatchers km2
        , keyMapContentsMatchers =
              keyMapContentsMatchers km1 <> keyMapContentsMatchers km2
        , keyMapTimestampsMatchers =
              keyMapTimestampsMatchers km1 <> keyMapTimestampsMatchers km2
        , keyMapPropertiesMatchers =
              keyMapPropertiesMatchers km1 <> keyMapPropertiesMatchers km2
        , keyMapStateHistoryMatchers =
              keyMapStateHistoryMatchers km1 <> keyMapStateHistoryMatchers km2
        , keyMapTagsMatchers = keyMapTagsMatchers km1 <> keyMapTagsMatchers km2
        , keyMapLogbookMatchers =
              keyMapLogbookMatchers km1 <> keyMapLogbookMatchers km2
        , keyMapAnyMatchers = keyMapAnyMatchers km1 <> keyMapAnyMatchers km2
        }

instance Monoid KeyMap where
    mempty =
        KeyMap
        { keyMapHelpMatchers = mempty
        , keyMapEmptyMatchers = mempty
        , keyMapEntryMatchers = mempty
        , keyMapHeaderMatchers = mempty
        , keyMapContentsMatchers = mempty
        , keyMapTimestampsMatchers = mempty
        , keyMapPropertiesMatchers = mempty
        , keyMapStateHistoryMatchers = mempty
        , keyMapTagsMatchers = mempty
        , keyMapLogbookMatchers = mempty
        , keyMapAnyMatchers = mempty
        }

type KeyMappings = [KeyMapping]

data KeyMapping
    = MapVtyExactly KeyPress
                    Action
    | MapAnyTypeableChar (ActionUsing Char)
    | MapCatchAll Action
    | MapCombination KeyPress
                     KeyMapping

data Action = Action
    { actionName :: Text
    , actionFunc :: SmosM ()
    , actionDescription :: Text
    } deriving (Generic)

action :: Text -> SmosM () -> Action
action name func =
    Action {actionName = name, actionFunc = func, actionDescription = ""}

data ActionUsing a = ActionUsing
    { actionUsingName :: Text
    , actionUsingFunc :: a -> SmosM ()
    , actionUsingDescription :: Text
    } deriving (Generic)

instance Contravariant ActionUsing where
    contramap func a = a {actionUsingFunc = \b -> actionUsingFunc a $ func b}

actionUsing :: Text -> (a -> SmosM ()) -> ActionUsing a
actionUsing name func =
    ActionUsing
    { actionUsingName = name
    , actionUsingFunc = func
    , actionUsingDescription = ""
    }

data AnyAction
    = PlainAction Action
    | UsingCharAction (ActionUsing Char)

type SmosEvent = BrickEvent ResourceName ()

type SmosM = MkSmosM SmosConfig ResourceName SmosState

runSmosM ::
       SmosConfig
    -> SmosState
    -> SmosM a
    -> EventM ResourceName (MStop a, SmosState)
runSmosM = runMkSmosM

data SmosState = SmosState
    { smosStateFilePath :: Path Abs File
    , smosStateCursor :: EditorCursor
    , smosStateKeyHistory :: Seq KeyPress
    , smosStateCursorHistory :: [EditorCursor] -- From youngest to oldest
    , smosStateDebugInfo :: DebugInfo
    } deriving (Generic)

data KeyPress =
    KeyPress Key
             [Modifier]
    deriving (Show, Eq, Ord)

data DebugInfo = DebugInfo
    { debugInfoLastMatches :: Maybe (NonEmpty ActivationDebug)
    } deriving (Show, Eq, Generic)

data ActivationDebug = ActivationDebug
    { activationDebugPrecedence :: Precedence
    , activationDebugPriority :: Priority
    , activationDebugMatch :: Seq KeyPress
    , activationDebugName :: Text
    } deriving (Show, Eq, Generic)

data Priority
    = CatchAll
    | MatchAnyChar
    | MatchExact -- Has higher priority.
    deriving (Show, Eq, Ord)

data Precedence
    = AnyMatcher -- Has higher priority.
    | SpecificMatcher
    deriving (Show, Eq, Ord)

newtype ResourceName =
    ResourceName Text
    deriving (Show, Eq, Ord, Generic, IsString)

newtype MkSmosM c n s a = MkSmosM
    { unMkSmosM :: NextT (StateT s (ReaderT c (EventM n))) a
    } deriving ( Generic
               , Functor
               , Applicative
               , Monad
               , MonadState s
               , MonadReader c
               )

instance MonadIO (MkSmosM c n s) where
    liftIO = MkSmosM . liftIO

runMkSmosM :: c -> s -> MkSmosM c n s a -> EventM n (MStop a, s)
runMkSmosM conf initState act =
    runReaderT (runStateT (runNextT (unMkSmosM act)) initState) conf

data MStop a
    = Stop
    | Continue a
    deriving (Show, Eq, Generic)

instance Validity a => Validity (MStop a)

instance Functor MStop where
    fmap _ Stop = Stop
    fmap f (Continue a) = Continue $ f a

newtype NextT m a = NextT
    { runNextT :: m (MStop a)
    }

instance Functor m => Functor (NextT m) where
    fmap f (NextT func) = NextT $ fmap (f <$>) func

instance Monad m => Applicative (NextT m) where
    pure = NextT . pure . Continue
    (NextT f1) <*> (NextT f2) =
        NextT $ do
            n1 <- f1
            case n1 of
                Stop -> pure Stop
                Continue f -> do
                    n2 <- f2
                    pure $ f <$> n2

instance Monad m => Monad (NextT m) where
    (NextT ma) >>= fm =
        NextT $ do
            na <- ma
            case na of
                Stop -> pure Stop
                Continue a -> runNextT $ fm a

instance MonadTrans NextT where
    lift func = NextT $ Continue <$> func

instance MonadIO m => MonadIO (NextT m) where
    liftIO = lift . liftIO

instance MonadState s m => MonadState s (NextT m) where
    get = NextT $ Continue <$> get
    put = NextT . fmap Continue . put

instance MonadReader s m => MonadReader s (NextT m) where
    ask = NextT $ Continue <$> ask
    local func (NextT m) = NextT $ local func m

stop :: Action
stop =
    Action
    { actionName = "stop"
    , actionDescription = "Stop Smos"
    , actionFunc = MkSmosM $ NextT $ pure Stop
    }
