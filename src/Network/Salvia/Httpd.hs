module Network.Salvia.Httpd

  -- Httpd.Core.Config
  ( Config (..)
  , defaultConfig

  -- Httpd.Core.Aspects
  , forRequest
  , forResponse

  , ServerM
  , server

  , HttpM
  , http
  , request
  , response

  , PeerM
  , rawSock
  , sock
  , peer

  , QueueM
  , enqueue
  , dequeue

  , FlushM
  , flushHeaders
  , flushQueue

  , BodyM 
  , body
  )
where

-- Abstract implementation.
import Network.Salvia.Core.Config
import Network.Salvia.Core.Aspects
-- import Network.Salvia.Core.Context

