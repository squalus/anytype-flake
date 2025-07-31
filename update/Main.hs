module Main where

import Control.Exception
import Data.Text (Text)
import Data.Text.Encoding.Base64 (decodeBase64Untyped)
import Data.Vector (Vector)
import GHC.Generics
import GitHub (github')
import Options.Applicative
import Options.Applicative.Text
import System.Directory (getCurrentDirectory)
import System.FilePath

import Data.Aeson qualified
import Data.List qualified
import Data.Text qualified
import Data.Text.IO qualified
import Data.Vector qualified
import GitHub qualified
import Prefetch qualified
import Text.Casing qualified

newtype Command = Update UpdateConfig

data UpdateConfig = UpdateConfig
  { updateConfigFlakeRoot :: !(Maybe FilePath)
  , updateConfigTag :: !(Maybe Text)
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
    sub = hsubparser parseUpdate

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
    <*> optional
      ( textOption
          ( mconcat
              [ long "tag"
              , short 't'
              , help "anytype-ts tag to use"
              , metavar "TAG"
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

getReleaseByTag :: Text -> Text -> Text -> IO GitHub.Release
getReleaseByTag owner repo tag =
  github' (GitHub.releaseByTagNameR (GitHub.mkOwnerName owner) (GitHub.mkRepoName repo) tag) >>= \case
    Left x -> (fail . show) x
    Right x -> pure x

getHeartVersion :: Text -> IO Text
getHeartVersion tsTag = do
  middlewareVersionContent <-
    github' (GitHub.contentsForR "anyproto" "anytype-ts" "middleware.version" (Just tsTag)) >>= \case
      Left x -> fail ("Error fetching anytype-ts middleware.version file: " <> show x)
      Right x -> pure x
  middlewareVersionContentFile <- case middlewareVersionContent of
    GitHub.ContentFile cfd -> pure cfd
    _ -> fail "Unexpected content type of middleware.version"
  let middlewareVersionContentText = (Data.Text.strip . GitHub.contentFileContent) middlewareVersionContentFile
  case decodeBase64Untyped middlewareVersionContentText of
    Left x -> fail ("Error in base64 decode of middleware.version file" <> Data.Text.unpack x)
    Right x -> pure x

getHeartGoMod :: Text -> IO Text
getHeartGoMod heartTag = do
  goModContent <-
    github' (GitHub.contentsForR "anyproto" "anytype-heart" "go.mod" (Just heartTag)) >>= \case
      Left x -> fail ("Error fetching anytype-heart go.mod file: " <> show x)
      Right x -> pure x
  goModContentFile <- case goModContent of
    GitHub.ContentFile cfd -> pure cfd
    _ -> fail "Unexpected content type of go.mod"
  let goModContentText = (Data.Text.strip . GitHub.contentFileContent) goModContentFile
      joined = mconcat . Data.Text.lines $ goModContentText
  case decodeBase64Untyped joined of
    Left x -> fail ("Error in base64 decode of anytype-heart go.mod file" <> Data.Text.unpack x)
    Right x -> pure x

getTantivyTag :: Text -> Maybe Text
getTantivyTag heartGoMod = do
  let lines' = Data.Text.lines heartGoMod
  line <- Data.List.find (Data.Text.isInfixOf "tantivy-go") lines'
  let words' = Data.Text.words (Data.Text.strip line)
  case words' of
    ["github.com/anyproto/tantivy-go", tag] -> pure tag
    _ -> Nothing

heartReleaseByTag :: Text -> IO GitHub.Release
heartReleaseByTag tag = do
  github' (GitHub.releaseByTagNameR "anyproto" "anytype-heart" tag) >>= \case
    Left x -> fail ("Error fetching anytype-heart release: " <> show x)
    Right x -> pure x

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
  let heartLockfilePath = flakeRoot </> "anytype-heart/src.json"
      tsLockfilePath = flakeRoot </> "anytype/src.json"
      tantivyLockfilePath = flakeRoot </> "libtantivy-go/src.json"
  tsRelease <- case updateConfigTag c of
    Nothing ->
      getLatestRelease "anyproto" "anytype-ts" >>= \case
        Nothing -> fail "Error finding latest stable anytype-ts release"
        Just x -> pure x
    Just tag -> getReleaseByTag "anyproto" "anytype-ts" tag
  let tsTag = GitHub.releaseTagName tsRelease

  heartVersion <- getHeartVersion tsTag
  Data.Text.IO.putStrLn $ mconcat ["anytype-ts middleware.version: ", heartVersion]
  let heartTag = "v" <> heartVersion
  Data.Text.IO.putStrLn $ mconcat ["anytype-heart tag: ", heartTag]
  heartGoMod <- getHeartGoMod heartTag
  tantivyTag <- maybe (fail "Unable to find tantivy-go tag") pure $ getTantivyTag heartGoMod
  Data.Text.IO.putStrLn $ mconcat ["tantivy-go tag: ", tantivyTag]

  updateGithubLockfile "anyproto" "anytype-ts" tsTag tsLockfilePath
  updateGithubLockfile "anyproto" "anytype-heart" heartTag heartLockfilePath
  updateGithubLockfile "anyproto" "tantivy-go" tantivyTag tantivyLockfilePath
