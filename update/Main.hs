module Main where

import Control.Exception
import Data.ByteString (ByteString)
import Data.ByteString.Base64 (encodeBase64)
import Data.Text (Text)
import Data.Text.Encoding.Base64 (decodeBase64)
import Data.Vector (Vector)
import GHC.Generics
import GitHub (github')
import Options.Applicative
import System.Directory (getCurrentDirectory)
import System.FilePath

import Data.Aeson qualified
import Data.Text qualified
import Data.Text.IO qualified
import Data.Vector qualified
import GitHub qualified
import Prefetch qualified
import Text.Casing qualified

data Command = Update UpdateConfig

data UpdateConfig = UpdateConfig
  { updateConfigFlakeRoot :: !(Maybe FilePath)
  }

main :: IO ()
main = customExecParser opts parseCommand >>= runCommand
  where
    opts = prefs (showHelpOnEmpty <> showHelpOnError)

runCommand :: Command -> IO ()
runCommand (Update c) = runUpdate c

parseCommand :: ParserInfo Command
parseCommand =
  info (sub <**> helper) $
    mconcat
      [ fullDesc
      , progDesc "Flake update"
      ]
  where
    sub = hsubparser (parseUpdate)

parseUpdate :: Mod CommandFields Command
parseUpdate = command "update" (info (Update <$> parseUpdateConfig) (fullDesc <> progDesc "Update"))

parseUpdateConfig :: Parser UpdateConfig
parseUpdateConfig =
  UpdateConfig
    <$> optional
      ( strOption
          ( mconcat
              [ long "flake-root"
              , short 'f'
              , help "Root directory of flake"
              , metavar "FLAKE_ROOT"
              ]
          )
      )

firstMatch :: (a -> Bool) -> Vector a -> Maybe a
firstMatch fn v = firstMatch' (Data.Vector.toList v)
  where
    firstMatch' [] = Nothing
    firstMatch' (x : xs) = if fn x then Just x else firstMatch' xs

isTSReleaseStable :: GitHub.Release -> Bool
isTSReleaseStable release =
  let
    tagName = GitHub.releaseTagName release
    isVersion = Data.Text.isPrefixOf "v" tagName
    isAlpha = Data.Text.isSuffixOf "-alpha" tagName
    isBeta = Data.Text.isSuffixOf "-beta" tagName
  in
    isVersion && not isAlpha && not isBeta

getLatestRelease :: Text -> Text -> IO (Maybe GitHub.Release)
getLatestRelease owner repo = do
  releases <-
    github' (GitHub.releasesR (GitHub.mkOwnerName owner) (GitHub.mkRepoName repo) (GitHub.FetchAtLeast 15)) >>= \case
      Left x -> fail ("Error fetching anytype-ts releases: " <> show x)
      Right x -> pure x
  pure (firstMatch isTSReleaseStable releases)

getTSMiddlewareVersion :: Text -> IO Text
getTSMiddlewareVersion tsTag = do
  middlewareVersionContent <-
    github' (GitHub.contentsForR "anyproto" "anytype-ts" "middleware.version" (Just tsTag)) >>= \case
      Left x -> fail ("Error fetching anytype-ts middleware.version file: " <> show x)
      Right x -> pure x
  middlewareVersionContentFile <- case middlewareVersionContent of
    GitHub.ContentFile cfd -> pure cfd
    _ -> fail "Unexpected content type of middleware.version"
  let middlewareVersionContentText = (Data.Text.strip . GitHub.contentFileContent) middlewareVersionContentFile
  case decodeBase64 middlewareVersionContentText of
    Left x -> fail ("Error in base64 decode of middleware.version file" <> Data.Text.unpack x)
    Right x -> pure x

heartReleaseByTag :: Text -> IO GitHub.Release
heartReleaseByTag tag = do
  github' (GitHub.releaseByTagNameR "anyproto" "anytype-heart" tag) >>= \case
    Left x -> fail ("Error fetching anytype-heart release: " <> show x)
    Right x -> pure x

getHeartReleaseAsset :: Text -> IO (GitHub.Release, GitHub.ReleaseAsset)
getHeartReleaseAsset heartTag = do
  release <- heartReleaseByTag heartTag
  case getHeartBinaryAsset release of
    Nothing -> fail "Couldn't find release asset in anytype-heart"
    Just x -> pure (release, x)

getHeartBinaryAsset :: GitHub.Release -> Maybe GitHub.ReleaseAsset
getHeartBinaryAsset release =
  let
    expectedName = mconcat ["js_", GitHub.releaseTagName release, "_linux-amd64.tar.gz"]
  in
    firstMatch (\asset -> GitHub.releaseAssetName asset == expectedName) (GitHub.releaseAssets release)

encodeSha256 :: ByteString -> Text
encodeSha256 bs = "sha256-" <> encodeBase64 bs

data FetchurlLockfile = FetchurlLockfile
  { fetchurlLockfileURL :: !Text
  , fetchurlLockfileHash :: !Text
  , fetchurlLockfileVersion :: !Text
  }
  deriving (Show, Eq, Generic)

data GithubLockfile = GithubLockfile
  { githubLockfileRev :: !Text
  , githubLockfileHash :: !Text
  , githubLockfileVersion :: !Text
  }
  deriving (Show, Eq, Generic)

defaultLabels :: String -> String
defaultLabels = Text.Casing.toQuietSnake . Text.Casing.dropPrefix . Text.Casing.dropPrefix . Text.Casing.fromHumps

localOptions :: Data.Aeson.Options
localOptions = Data.Aeson.defaultOptions{Data.Aeson.fieldLabelModifier = defaultLabels}

instance Data.Aeson.FromJSON FetchurlLockfile where
  parseJSON = Data.Aeson.genericParseJSON localOptions

instance Data.Aeson.ToJSON FetchurlLockfile where
  toEncoding = Data.Aeson.genericToEncoding localOptions

instance Data.Aeson.FromJSON GithubLockfile where
  parseJSON = Data.Aeson.genericParseJSON localOptions

instance Data.Aeson.ToJSON GithubLockfile where
  toEncoding = Data.Aeson.genericToEncoding localOptions

readJSON :: (Data.Aeson.FromJSON a) => FilePath -> IO (Maybe a)
readJSON fp = do
  catch @SomeException (Just <$> readJSON') $ \ex -> do
    print ex
    pure Nothing
  where
    readJSON' =
      Data.Aeson.eitherDecodeFileStrict fp >>= \case
        Left err -> fail err
        Right x -> pure x

updateGithubLockfile :: Text -> Text -> Text -> FilePath -> IO ()
updateGithubLockfile owner repo rev path = do
  Data.Text.IO.putStrLn $ mconcat ["tag: ", rev]
  prevLockfile <- readJSON path
  if (githubLockfileRev <$> prevLockfile) == Just rev
    then putStrLn "tag matches lockfile"
    else putStrLn "tag does not match lockfile"
  putStrLn "Downloading source..."
  hash <- Prefetch.prefetchGithub owner repo rev
  putStrLn "Downloading source...done"
  Data.Text.IO.putStrLn $ mconcat ["hash: ", hash]
  let nextLockfile =
        GithubLockfile
          { githubLockfileHash = hash
          , githubLockfileRev = rev
          , githubLockfileVersion = rev
          }
  if prevLockfile == Just nextLockfile
    then putStrLn "lockfile matches"
    else do
      putStrLn "lockfile does not match"
      putStrLn $ mconcat ["Writing ", path, "..."]
      Data.Aeson.encodeFile path nextLockfile
      putStrLn $ mconcat ["Writing ", path, "...done"]

runUpdate :: UpdateConfig -> IO ()
runUpdate c = do
  flakeRoot <- maybe getCurrentDirectory pure (updateConfigFlakeRoot c)
  let heartBinaryLockfilePath = flakeRoot </> "anytype-heart-bin.json"
      heartLockfilePath = flakeRoot </> "anytype-heart-src.json"
      tsLockfilePath = flakeRoot </> "anytype-ts-src.json"
  prevHeartBinaryLockfile <- readJSON heartBinaryLockfilePath
  tsRelease <-
    getLatestRelease "anyproto" "anytype-ts" >>= \case
      Nothing -> fail "Error finding latest stable anytype-ts release"
      Just x -> pure x
  let tsTag = GitHub.releaseTagName tsRelease

  middlewareVersion <- getTSMiddlewareVersion tsTag
  Data.Text.IO.putStrLn $ mconcat ["anytype-ts middleware.version: ", middlewareVersion]
  let heartTag = "v" <> middlewareVersion
  Data.Text.IO.putStrLn $ mconcat ["anytype-heart tag: ", heartTag]
  if (fetchurlLockfileVersion <$> prevHeartBinaryLockfile) == Just heartTag
    then putStrLn "anytype-heart binary version matches lockfile"
    else putStrLn "anytype-heart binary version does not match lockfile"

  (_, heartReleaseAsset) <- getHeartReleaseAsset heartTag

  putStrLn "Downloading heart binary release asset..."
  prefetch <- Prefetch.prefetchGithubReleaseAsset heartReleaseAsset
  putStrLn "Downloading heart binary release asset...done"
  Data.Text.IO.putStrLn $ mconcat ["anytype-heart binary url: ", Prefetch.fetchurlResultURL prefetch]
  Data.Text.IO.putStrLn $ mconcat ["anytype-heart binary hash: ", Prefetch.fetchurlResultHash prefetch]
  let nextHeartBinaryLockfile =
        FetchurlLockfile
          { fetchurlLockfileHash = Prefetch.fetchurlResultHash prefetch
          , fetchurlLockfileURL = Prefetch.fetchurlResultURL prefetch
          , fetchurlLockfileVersion = heartTag
          }
  if prevHeartBinaryLockfile == Just nextHeartBinaryLockfile
    then putStrLn "anytype-heart binary lockfile matches"
    else do
      putStrLn "anytype-heart binary lockfile does not match"
      putStrLn $ mconcat ["Writing ", heartBinaryLockfilePath, "..."]
      Data.Aeson.encodeFile heartBinaryLockfilePath nextHeartBinaryLockfile
      putStrLn $ mconcat ["Writing ", heartBinaryLockfilePath, "...done"]

  updateGithubLockfile "anyproto" "anytype-ts" tsTag tsLockfilePath
  updateGithubLockfile "anyproto" "anytype-heart" heartTag heartLockfilePath
