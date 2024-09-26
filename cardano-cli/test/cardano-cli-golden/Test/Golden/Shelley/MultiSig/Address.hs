{-# LANGUAGE OverloadedStrings #-}

module Test.Golden.Shelley.MultiSig.Address where

import           Test.Cardano.CLI.Util as OP

import           Hedgehog (Property)
import qualified Hedgehog.Extras.Test.Base as H
import qualified Hedgehog.Extras.Test.File as H
import qualified Hedgehog.Extras.Test.Golden as H

{- HLINT ignore "Use camelCase" -}

hprop_golden_shelleyAllMultiSigAddressBuild :: Property
hprop_golden_shelleyAllMultiSigAddressBuild = propertyOnce . H.moduleWorkspace "tmp" $ \_ -> do
  allMultiSigFp <- noteInputFile "test/cardano-cli-golden/files/input/shelley/multisig/scripts/all"

  allMultiSigAddress <-
    execCardanoCLI
      [ "latest"
      , "address"
      , "build"
      , "--payment-script-file"
      , allMultiSigFp
      , "--mainnet"
      ]

  goldenAllMultiSigAddrFp <-
    noteInputFile "test/cardano-cli-golden/files/input/shelley/multisig/addresses/all"

  goldenAllMs <- H.readFile goldenAllMultiSigAddrFp

  equivalence allMultiSigAddress goldenAllMs

hprop_golden_shelleyAnyMultiSigAddressBuild :: Property
hprop_golden_shelleyAnyMultiSigAddressBuild = propertyOnce . H.moduleWorkspace "tmp" $ \_ -> do
  anyMultiSigFp <- noteInputFile "test/cardano-cli-golden/files/input/shelley/multisig/scripts/any"

  anyMultiSigAddress <-
    execCardanoCLI
      [ "latest"
      , "address"
      , "build"
      , "--payment-script-file"
      , anyMultiSigFp
      , "--mainnet"
      ]

  goldenAnyMultiSigAddrFp <-
    noteInputFile "test/cardano-cli-golden/files/input/shelley/multisig/addresses/any"

  goldenAnyMs <- H.readFile goldenAnyMultiSigAddrFp

  equivalence anyMultiSigAddress goldenAnyMs

hprop_golden_shelleyAtLeastMultiSigAddressBuild :: Property
hprop_golden_shelleyAtLeastMultiSigAddressBuild = propertyOnce . H.moduleWorkspace "tmp" $ \_ -> do
  atLeastMultiSigFp <-
    noteInputFile "test/cardano-cli-golden/files/input/shelley/multisig/scripts/atleast"

  atLeastMultiSigAddress <-
    execCardanoCLI
      [ "latest"
      , "address"
      , "build"
      , "--payment-script-file"
      , atLeastMultiSigFp
      , "--mainnet"
      ]

  goldenAtLeastMultiSigAddrFp <-
    H.note "test/cardano-cli-golden/files/golden/shelley/multisig/addresses/atleast"

  H.diffVsGoldenFile atLeastMultiSigAddress goldenAtLeastMultiSigAddrFp
