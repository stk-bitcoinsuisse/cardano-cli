{- HLINT ignore "Use camelCase" -}

module Test.Golden.Governance.Action where

import           Control.Monad (void)

import qualified Test.Cardano.CLI.Util as H
import           Test.Cardano.CLI.Util

import           Hedgehog (Property)
import qualified Hedgehog.Extras.Test.Base as H
import qualified Hedgehog.Extras.Test.Golden as H
import qualified Hedgehog.Extras as H

hprop_golden_governance_action_create_constitution :: Property
hprop_golden_governance_action_create_constitution =
  propertyOnce . H.moduleWorkspace "tmp" $ \tempDir -> do
    stakeAddressVKeyFile <- noteTempFile tempDir "stake-address.vkey"
    stakeAddressSKeyFile <- noteTempFile tempDir "stake-address.skey"

    void $ execCardanoCLI
      [ "legacy", "stake-address", "key-gen"
      , "--verification-key-file", stakeAddressVKeyFile
      , "--signing-key-file", stakeAddressSKeyFile
      ]

    actionFile <- noteTempFile tempDir "create-constitution.action"
    redactedActionFile <- noteTempFile tempDir "create-constitution.action.redacted"

    proposalHash <- execCardanoCLI
      [ "conway", "governance", "hash"
      , "--text", "whatever "]

    void $ execCardanoCLI
      [ "conway", "governance", "action", "create-constitution"
      , "--mainnet"
      , "--anchor-data-hash", "c7ddb5b493faa4d3d2d679847740bdce0c5d358d56f9b1470ca67f5652a02745"
      , "--anchor-url", proposalHash
      , "--governance-action-deposit", "10"
      , "--stake-verification-key-file", stakeAddressVKeyFile
      , "--out-file", actionFile
      , "--constitution-anchor-url", "constitution-dummy-url"
      , "--constitution-anchor-metadata", "This is a test constitution."
      ]

    goldenActionFile <-  H.note "test/cardano-cli-golden/files/golden/governance/action/create-constitution-for-stake-address.action.golden"

    -- Remove cbor hex from comparison, as it's not stable
    H.redactJsonField "cborHex" "<cborHex>" actionFile redactedActionFile

    H.diffFileVsGoldenFile redactedActionFile goldenActionFile

hprop_golden_conway_governance_action_view_constitution_json :: Property
hprop_golden_conway_governance_action_view_constitution_json =
  propertyOnce . H.moduleWorkspace "tmp" $ \tempDir -> do
    stakeAddressVKeyFile <- H.note "test/cardano-cli-golden/files/input/governance/stake-address.vkey"
    hashFile <- noteTempFile tempDir "hash.txt"

    actionFile <- noteTempFile tempDir "action"

    -- We go through a file for the hash, to test --out-file
    void $ execCardanoCLI
      [ "conway", "governance", "hash"
      , "--text", "whatever "
      , "--out-file", hashFile
      ]

    proposalHash <- H.readFile hashFile

    void $ execCardanoCLI
      [ "conway", "governance", "action", "create-constitution"
      , "--mainnet"
      , "--anchor-data-hash", proposalHash
      , "--anchor-url", "proposal-dummy-url"
      , "--governance-action-deposit", "10"
      , "--stake-verification-key-file", stakeAddressVKeyFile
      , "--out-file", actionFile
      , "--constitution-anchor-url", "constitution-dummy-url"
      , "--constitution-anchor-metadata", "This is a test constitution."
      ]

    goldenActionViewFile <- H.note "test/cardano-cli-golden/files/golden/governance/action/view/create-constitution.action.view"
    actionView <- execCardanoCLI
      [ "conway", "governance", "action", "view"
      , "--action-file", actionFile
      ]
    H.diffVsGoldenFile actionView goldenActionViewFile

hprop_golden_conway_governance_action_view_update_committee_yaml :: Property
hprop_golden_conway_governance_action_view_update_committee_yaml =
  propertyOnce . H.moduleWorkspace "tmp" $ \tempDir -> do
    stakeAddressVKeyFile <- H.note "test/cardano-cli-golden/files/input/governance/stake-address.vkey"

    actionFile <- noteTempFile tempDir "action"

    void $ execCardanoCLI
      [ "conway", "governance", "action", "update-committee"
      , "--mainnet"
      , "--governance-action-deposit", "10"
      , "--stake-verification-key-file", stakeAddressVKeyFile
      , "--anchor-url", "proposal-dummy-url"
      , "--anchor-data-hash", "c7ddb5b493faa4d3d2d679847740bdce0c5d358d56f9b1470ca67f5652a02745"
      , "--quorum", "0.61"
      , "--out-file", actionFile
      ]

    goldenActionViewFile <- H.note "test/cardano-cli-golden/files/golden/governance/action/view/update-committee.action.view"
    actionView <- execCardanoCLI
      [ "conway", "governance", "action", "view"
      , "--action-file", actionFile
      , "--output-format", "yaml"
      ]
    H.diffVsGoldenFile actionView goldenActionViewFile

hprop_golden_conway_governance_action_view_create_info_json_outfile :: Property
hprop_golden_conway_governance_action_view_create_info_json_outfile =
  propertyOnce . H.moduleWorkspace "tmp" $ \tempDir -> do
    stakeAddressVKeyFile <- H.note "test/cardano-cli-golden/files/input/governance/stake-address.vkey"

    actionFile <- noteTempFile tempDir "action"

    void $ execCardanoCLI
      [ "conway", "governance", "action", "create-info"
      , "--testnet"
      , "--governance-action-deposit", "10"
      , "--stake-verification-key-file", stakeAddressVKeyFile
      , "--anchor-url", "proposal-dummy-url"
      , "--anchor-data-hash", "c7ddb5b493faa4d3d2d679847740bdce0c5d358d56f9b1470ca67f5652a02745"
      , "--out-file", actionFile
      ]

    actionViewFile <- noteTempFile tempDir "action-view"
    goldenActionViewFile <- H.note "test/cardano-cli-golden/files/golden/governance/action/view/create-info.action.view"
    void $ execCardanoCLI
      [ "conway", "governance", "action", "view"
      , "--action-file", actionFile
      , "--out-file", actionViewFile
      ]
    H.diffFileVsGoldenFile actionViewFile goldenActionViewFile

hprop_golden_governanceActionCreateNoConfidence :: Property
hprop_golden_governanceActionCreateNoConfidence =
  propertyOnce . H.moduleWorkspace "tmp" $ \tempDir -> do
    stakeAddressVKeyFile <- noteInputFile "test/cardano-cli-golden/files/input/governance/stake-address.vkey"

    actionFile <- noteTempFile tempDir "action"

    void $ execCardanoCLI
      [ "conway", "governance", "action", "create-no-confidence"
      , "--mainnet"
      , "--governance-action-deposit", "10"
      , "--stake-verification-key-file", stakeAddressVKeyFile
      , "--anchor-url", "proposal-dummy-url"
      , "--anchor-data-hash", "c7ddb5b493faa4d3d2d679847740bdce0c5d358d56f9b1470ca67f5652a02745"
      , "--governance-action-index", "5"
      , "--governance-action-tx-id", "b1015258a99351c143a7a40b7b58f033ace10e3cc09c67780ed5b2b0992aa60a"
      , "--out-file", actionFile
      ]

    actionViewFile <- noteTempFile tempDir "action-view"
    goldenActionViewFile <- H.note "test/cardano-cli-golden/files/golden/governance/action/view/create-no-confidence.action.view"
    void $ execCardanoCLI
      [ "conway", "governance", "action", "view"
      , "--action-file", actionFile
      , "--out-file", actionViewFile
      ]
    H.diffFileVsGoldenFile actionViewFile goldenActionViewFile
