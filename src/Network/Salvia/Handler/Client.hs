module Network.Salvia.Handler.Client where

import Control.Monad.State
import Data.Record.Label
import Network.Protocol.Http
import Network.Protocol.Uri
import Network.Salvia.Core.Aspects
import Network.Salvia.Handler.Body
import Network.Salvia.Handler.Parser
import Network.Salvia.Handler.Printer
import System.IO

hGetRequest :: (HttpM Request m, SendM m) => String -> m ()
hGetRequest s =
  do let u = toURI s
     request $
       do method     =: GET
          uri        =: (lget path u ++ "?" ++ lget query u)
          hostname   =: Just (show $ lget authority u)
          userAgent  =: Just "salvia-client"
          connection =: Just "close"
     hRequestPrinter
     return ()

hClientEnvironment
  :: (SocketM m, HttpM Response m, MonadIO m) =>
     (String -> m a) -> m a -> m (Maybe a)
hClientEnvironment = hResponseParser (4 * 1000)


cHandler :: (HttpM Request m, SocketM m, MonadIO m, HttpM Response m) => m ()
cHandler =
  do q <- request get
     liftIO (print q)
     r <- response get
     liftIO (print r)
     c <- asASCII hResponseContents
     liftIO (putStr ((\(Just s) -> s) c))
     return ()



