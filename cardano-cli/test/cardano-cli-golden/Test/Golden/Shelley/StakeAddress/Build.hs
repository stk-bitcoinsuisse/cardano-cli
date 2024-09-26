{-# LANGUAGE OverloadedStrings #-}

module Test.Golden.Shelley.StakeAddress.Build where

import           Test.Cardano.CLI.Util as OP

import           Hedgehog (Property)
import qualified Hedgehog.Extras.Test.Base as H
import qualified Hedgehog.Extras.Test.File as H

{- HLINT ignore "Use camelCase" -}

hprop_golden_shelleyStakeAddressBuild :: Property
hprop_golden_shelleyStakeAddressBuild = propertyOnce . H.moduleWorkspace "tmp" $ \_ -> do
  verificationKeyFile <-
    noteInputFile "test/cardano-cli-golden/files/input/shelley/keys/stake_keys/verification_key"
  goldenRewardAddressFile <-
    noteInputFile "test/cardano-cli-golden/files/input/shelley/keys/stake_keys/reward_address"

  rewardAddress <-
    execCardanoCLI
      [ "latest"
      , "stake-address"
      , "build"
      , "--mainnet"
      , "--staking-verification-key-file"
      , verificationKeyFile
      ]

  goldenRewardsAddress <- H.readFile goldenRewardAddressFile

  equivalence rewardAddress goldenRewardsAddress
