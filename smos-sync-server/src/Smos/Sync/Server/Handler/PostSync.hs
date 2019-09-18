module Smos.Sync.Server.Handler.PostSync
  ( handlePostSync
  ) where

import Smos.Sync.Server.Handler.Import

import Data.UUID.V4 as UUID

import Control.Concurrent.STM
import Control.Monad.Reader

import qualified Data.Mergeful as Mergeful

handlePostSync :: SyncRequest -> SyncHandler SyncResponse
handlePostSync request = do
  var <- asks serverEnvStoreVar
  store <- liftIO $ readTVarIO var
  (items, newStore) <-
    Mergeful.processServerSync (liftIO UUID.nextRandom) store request
  serverId <- asks serverEnvServerUUID
  storeFile <- asks serverEnvStoreFile
  liftIO $ do
    atomically $ writeTVar var newStore
    let newServerStore =
          ServerStore
            {serverStoreServerUUID = serverId, serverStoreItems = newStore}
    saveStore storeFile newServerStore
  let resp =
        SyncResponse
          {syncResponseServerId = serverId, syncResponseItems = items}
  pure resp
