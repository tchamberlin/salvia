module Network.Salvia.Handler.CGI (hCGI) where {- doc ok -}

import Control.Applicative
import Data.Char
import Data.List
import Data.List.Split
import Data.Maybe
import Control.Concurrent
import Control.Monad.State
import Data.Record.Label
import Network.Protocol.Http hiding (hostname)
import Network.Protocol.Uri
import Network.Salvia.Core.Aspects
import Network.Salvia.Handler.Parser
import Network.Salvia.Handler.Error
import Network.Salvia.Core.Config
import System.IO
import System.Process
import Text.Parsec hiding (many, (<|>))
import qualified Data.ByteString.Lazy as L
import Data.Map (toList)

-- | Handler to run CGI scripts.

hCGI :: (MonadIO m, HttpM Request m, BodyM Request m, HttpM Response m, SendM m, ConfigM m) => FilePath -> m ()
hCGI fn =
  do cfg     <- config
     hdrs    <- request (getM headers)
     _query  <- request (getM (query % asUri))
     _path   <- request (getM (path % asUri))
     _method <- request (getM method)

     -- Helper function to convert all headers to environment variables.
     let headerDecls =
           map (\(a, b) -> ("HTTP_" ++ (map toUpper . intercalate "_" . splitOn "-") a, b))
             . toList . unHeaders

     -- Set the of expoerted server knowledge.
     let envs =
             ("GATEWAY_INTERFACE", "CGI/1.1")
           : ("REQUEST_METHOD",    show _method)
           : ("REQUEST_URI",       _path)
           : ("QUERY_STRING",      _query)
           : ("SERVER_SOFTWARE",   "Salvia")
           : ("SERVER_SIGNATURE",  "")
           : ("SERVER_PROTOCOL",   "HTTP/1.1")
           : ("SERVER_ADDR",       show (listenAddr cfg)) -- todo: fix show.
           : ("SERVER_ADMIN",      admin cfg)
           : ("SERVER_NAME",       hostname cfg)
           : ("SERVER_PORT",       show (listenPort cfg))
           : ("REMOTE_ADDR",       "") -- todo
           : ("REMOTE_PORT",       "") -- todo
           : ("SCRIPT_FILENAME",   "") -- todo
           : ("SCRIPT_NAME",       "") -- todo
           : headerDecls hdrs

     -- Start up the CGI script with the appropriate environment variables.
     (inp, out, _, pid) <- liftIO (runInteractiveProcess fn [] Nothing $ Just envs)

     -- Read the request body and fork a thread to spool the body to the CGI
     -- script's input. After spooling, or when there is no data, the scripts
     -- input will be closed.
     b <- body forRequest
     liftIO $
       case b of
         Nothing -> hClose inp
         Just b' -> forkIO (L.hPut inp b' >> hClose inp) >> return ()

     -- Read the headers produced by the CGI script and store them as the
     -- response headers of this handler.
     hs <- liftIO (readNonEmptyLines out)
     case parse pHeaders "" hs of
       Left e  -> hCustomError InternalServerError (show e)
       Right r -> response (headers =: r)

     -- Spool all data from the CGI script's output to the client. When
     -- finished, close the handle and wait for the script to terminate.
     spoolBs id out
     enqueue (const (hClose out <* waitForProcess pid))

