{-# LANGUAGE DeriveAnyClass, DeriveGeneric, DuplicateRecordFields, OverloadedStrings,
             LambdaCase, ScopedTypeVariables,NamedFieldPuns #-}

{-# OPTIONS_GHC -W #-}

module Gradescope where

import Control.Monad(forM_)
import GHC.Generics
import Data.Aeson ( ToJSON(toJSON), Value(..), Object )
import Data.Aeson.Encoding ( encodingToLazyByteString, value )
import Data.Text ( Text )
import qualified Data.Text as T
import qualified Data.ByteString.Lazy as B
import qualified Data.Aeson.KeyMap as Map
import Data.Generics ( everywhere', mkT )
import Data.Maybe ( catMaybes )
import System.Exit
import qualified System.Directory as D

data Visibility = Hidden
                | AfterDueDate
                | AfterPublished
                | Visible
  deriving Show

instance ToJSON Visibility where
  toJSON Hidden = String "hidden"
  toJSON AfterDueDate = String "after_due_date"
  toJSON AfterPublished = String "after_published"
  toJSON Visible = String "visible"

data AGTest = AGTest { score :: Maybe Double
                     , max_score :: Maybe Double
                     , number :: Text
                     , output :: Text
                     , visibility :: Visibility }
              deriving (Show, Generic, ToJSON)


data AGResult = AGResult { score :: Maybe Double
                         , execution_time :: Maybe Double
                         , output :: Text
                         , visibility :: Visibility
                         , tests :: [AGTest] }
            deriving (Show, Generic, ToJSON)

def_test = AGTest { score = Nothing
                  , max_score = Nothing
                  , number = ""
                  , output = ""
                  , visibility = Visible }

def_result = AGResult { score = Nothing
                      , execution_time = Nothing
                      , output = ""
                      , visibility = Visible
                      , tests = [] }

printTest :: AGTest -> IO ()
printTest AGTest{score,max_score,number,output} = do
  let ss :: Maybe Double -> Maybe Double -> String
      ss (Just s) (Just ms) = show s ++ "/" ++ show ms
      ss (Just s) Nothing = show s ++ " points"
      ss _ _ = "no score"
  putStrLn $ show number  ++ ") " ++ ss score max_score
  putStrLn (show output)

printResult :: AGResult -> IO ()
printResult r@AGResult {score,output,tests} = do
  putStrLn (show output)
  putStrLn $ "Score: " ++ show score ++ "/" ++ show (totalMaxScore r)
  forM_ tests $ printTest

-- remove any ("foo" : null) bindings in objects
noNulls :: Value -> Value
noNulls = everywhere' (mkT remove_null)
  where
    remove_null :: Object -> Object
    remove_null = Map.filter (\case Null -> False; _ -> True)

encodeNoNulls :: ToJSON a => a -> B.ByteString
encodeNoNulls = encodingToLazyByteString . value . noNulls . toJSON

totalMaxScore :: AGResult -> Double
totalMaxScore = sum . catMaybes . Prelude.map max_score . tests

totalScore :: AGResult -> Double
totalScore = sum . catMaybes . Prelude.map (score :: AGTest -> Maybe Double) . tests


recordResult :: AGResult -> IO ()
recordResult result = do
  putStr "Total maximum: "
  print (totalMaxScore result)
  writeResult result
  exitSuccess

writeResult :: AGResult -> IO ()
writeResult result = do
  let encoded = encodeNoNulls result
  let resultsDir = "/autograder/results/"
  dirExists <- D.doesDirectoryExist resultsDir
  if dirExists then
     B.writeFile (resultsDir ++ "results.json") encoded
  else
     printResult result
--  B.putStr encoded

tshow :: Show a => a -> Text
tshow = T.pack . show
