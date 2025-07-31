module Prefetch
  ( prefetchGithubReleaseAsset
  , FetchurlResult (..)
  , prefetchGithub
  )
where

import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.Conduit (ConduitM, await, mapInputM, mapOutput, runConduitRes, yield, (.|))
import Data.Maybe (listToMaybe, mapMaybe)
import Data.Text (Text)
import Data.Void (Void)
import System.Process.Typed

import Crypto.Hash.MD5 qualified as MD5
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson qualified
import Data.ByteString qualified
import Data.ByteString.Base64 qualified
import Data.Base64.Types qualified
import Data.Map qualified
import Data.Text qualified
import GitHub qualified
import Network.HTTP.Simple qualified
import Network.HTTP.Types.Header qualified
import Network.HTTP.Types.Status qualified

data FetchurlResult = FetchurlResult
  { fetchurlResultURL :: !Text
  -- ^ download URL
  , fetchurlResultHash :: !Text
  -- ^ SHA256 SRI hash
  }
  deriving (Show, Eq)

-- | Fetch the URL and hash of a github release asset
prefetchGithubReleaseAsset :: GitHub.ReleaseAsset -> IO FetchurlResult
prefetchGithubReleaseAsset asset = do
  let url = GitHub.releaseAssetBrowserDownloadUrl asset
      expectedSize = fromIntegral (GitHub.releaseAssetSize asset)
  req <- Network.HTTP.Simple.parseRequest (Data.Text.unpack url)
  sha256Ctx <-
    runConduitRes $
      Network.HTTP.Simple.httpSource req getSrc
        .| sha256Sink expectedSize
  let hashBs = SHA256.finalize sha256Ctx
  pure $
    FetchurlResult
      { fetchurlResultHash = encodeSha256 hashBs
      , fetchurlResultURL = url
      }
  where
    getSrc res = do
      let status = Network.HTTP.Simple.getResponseStatus res
      unless (Network.HTTP.Types.Status.statusIsSuccessful status) (fail (mconcat ["Get release asset status=", show status]))
      let headers = Network.HTTP.Simple.getResponseHeaders res
          maybeMD5Header = listToMaybe (mapMaybe (\(name, value) -> if name == md5HeaderName then Just value else Nothing) headers)
      md5BS <- case maybeMD5Header of
        Nothing -> fail "MD5 header not found"
        Just x -> case Data.ByteString.Base64.decodeBase64Untyped x of
          Left err -> fail (mconcat ["Error decoding MD5 header: ", Data.Text.unpack err])
          Right decoded -> pure decoded
      yield (ResponseDataMD5 md5BS)
      mapOutput ResponseDataContent (Network.HTTP.Simple.getResponseBody res)

data ResponseData
  = ResponseDataMD5 !ByteString
  | ResponseDataContent !ByteString

-- Take the MD5 as the first stream element and compute hashes of the remaining content
sha256Sink
  :: (MonadFail m)
  => Int
  -- ^ expected size from the release api
  -> ConduitM ResponseData Void m SHA256.Ctx
sha256Sink expectedSize =
  await >>= \case
    Nothing -> fail "no md5 sum received"
    Just dlData -> case dlData of
      ResponseDataMD5 md5 -> do
        let allToContent = \case
              ResponseDataMD5 _ -> fail "md5 received more than once"
              ResponseDataContent content -> pure content
        mapInputM allToContent (const (pure Nothing)) (sha256Sink' expectedSize md5 0 MD5.init SHA256.init)
      ResponseDataContent _ -> fail "no md5 sum received"

-- Compute and return SHA256 hash, verifying against a known MD5 hash
sha256Sink'
  :: (MonadFail m)
  => Int
  -- ^ expected size from the release api
  -> ByteString
  -- ^ expected md5
  -> Int
  -- ^ accumulator for the actual downloaded size
  -> MD5.Ctx
  -- ^ incremental md5 hash of content
  -> SHA256.Ctx
  -- ^ incremental sha256 hash of content
  -> ConduitM ByteString Void m SHA256.Ctx
sha256Sink' expectedSize expectedMD5 actualSize md5Ctx sha256Ctx =
  await >>= \case
    Nothing -> do
      unless (expectedSize == actualSize) $ fail (mconcat ["Size does not match. actualSize=", show actualSize, " expectedSize=", show expectedSize])
      let actualMD5 = MD5.finalize md5Ctx
      unless (expectedMD5 == actualMD5) $ fail (mconcat ["MD5 of release asset does not match"])
      pure sha256Ctx
    Just bs -> sha256Sink' expectedSize expectedMD5 (actualSize + Data.ByteString.length bs) (MD5.update md5Ctx bs) (SHA256.update sha256Ctx bs)

encodeSha256 :: ByteString -> Text
encodeSha256 bs = "sha256-" <> (Data.Base64.Types.extractBase64 . Data.ByteString.Base64.encodeBase64) bs

md5HeaderName :: Network.HTTP.Types.Header.HeaderName
md5HeaderName = "Content-MD5"

-- | Fetch the hash for a fetchGithub task
prefetchGithub
  :: Text
  -- ^ owner
  -> Text
  -- ^ repo
  -> Text
  -- ^ git revision
  -> IO Text
  -- ^ SHA256 SRI hash
prefetchGithub owner repo rev = do
  let config =
        setStdout byteStringOutput $
          proc "nix-prefetch-github" [Data.Text.unpack owner, Data.Text.unpack repo, "--rev", Data.Text.unpack rev, "--json"]
  (exit, stdout) <- readProcessStdout config
  case exit of
    ExitSuccess -> pure ()
    _ -> fail "nix-prefetch-github exited with bad status code"
  outMap :: Data.Map.Map String String <- case Data.Aeson.decode' stdout of
    Nothing -> fail "Error decoding nix-prefetch-github JSON output"
    Just x -> pure x
  hash <- case Data.Map.lookup "hash" outMap of
    Nothing -> fail "nix-prefetch-github JSON output missing hash key"
    Just x -> pure x
  pure (Data.Text.pack hash)
