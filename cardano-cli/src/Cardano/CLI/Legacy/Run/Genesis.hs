{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}

{-# OPTIONS_GHC -Wno-unticked-promoted-constructors #-}

module Cardano.CLI.Legacy.Run.Genesis
  ( runLegacyGenesisCmds
  ) where

import           Cardano.Api

import           Cardano.Chain.Common (BlockCount)
import           Cardano.CLI.EraBased.Run.Genesis
import           Cardano.CLI.Legacy.Commands.Genesis
import           Cardano.CLI.Types.Common
import           Cardano.CLI.Types.Errors.ShelleyGenesisCmdError

import           Control.Monad.Trans.Except (ExceptT)

runLegacyGenesisCmds :: LegacyGenesisCmds -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisCmds = \case
  GenesisKeyGenGenesis vk sk ->
    runLegacyGenesisKeyGenGenesisCmd vk sk
  GenesisKeyGenDelegate vk sk ctr ->
    runLegacyGenesisKeyGenDelegateCmd vk sk ctr
  GenesisKeyGenUTxO vk sk ->
    runLegacyGenesisKeyGenUTxOCmd vk sk
  GenesisCmdKeyHash vk ->
    runLegacyGenesisKeyHashCmd vk
  GenesisVerKey vk sk ->
    runLegacyGenesisVerKeyCmd vk sk
  GenesisTxIn vk nw mOutFile ->
    runLegacyGenesisTxInCmd vk nw mOutFile
  GenesisAddr vk nw mOutFile ->
    runLegacyGenesisAddrCmd vk nw mOutFile
  GenesisCreate fmt gd gn un ms am nw ->
    runLegacyGenesisCreateCmd fmt gd gn un ms am nw
  GenesisCreateCardano gd gn un ms am k slotLength sc nw bg sg ag cg mNodeCfg ->
    runLegacyGenesisCreateCardanoCmd gd gn un ms am k slotLength sc nw bg sg ag cg mNodeCfg
  GenesisCreateStaked fmt gd gn gp gl un ms am ds nw bf bp su relayJsonFp ->
    runLegacyGenesisCreateStakedCmd fmt gd gn gp gl un ms am ds nw bf bp su relayJsonFp
  GenesisHashFile gf ->
    runLegacyGenesisHashFileCmd gf

runLegacyGenesisKeyGenGenesisCmd :: ()
  => VerificationKeyFile Out
  -> SigningKeyFile Out
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisKeyGenGenesisCmd = runGenesisKeyGenGenesisCmd

runLegacyGenesisKeyGenDelegateCmd :: ()
  => VerificationKeyFile Out
  -> SigningKeyFile Out
  -> OpCertCounterFile Out
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisKeyGenDelegateCmd = runGenesisKeyGenDelegateCmd

runLegacyGenesisKeyGenUTxOCmd :: ()
  => VerificationKeyFile Out
  -> SigningKeyFile Out
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisKeyGenUTxOCmd = runGenesisKeyGenUTxOCmd

runLegacyGenesisKeyHashCmd :: VerificationKeyFile In -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisKeyHashCmd = runGenesisKeyHashCmd

runLegacyGenesisVerKeyCmd ::
     VerificationKeyFile Out
  -> SigningKeyFile In
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisVerKeyCmd = runGenesisVerKeyCmd

runLegacyGenesisTxInCmd :: ()
  => VerificationKeyFile In
  -> NetworkId
  -> Maybe (File () Out)
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisTxInCmd = runGenesisTxInCmd

runLegacyGenesisAddrCmd :: ()
  => VerificationKeyFile In
  -> NetworkId
  -> Maybe (File () Out)
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisAddrCmd = runGenesisAddrCmd

runLegacyGenesisCreateCmd :: ()
  => KeyOutputFormat
  -> GenesisDir
  -> Word  -- ^ num genesis & delegate keys to make
  -> Word  -- ^ num utxo keys to make
  -> Maybe SystemStart
  -> Maybe Lovelace
  -> NetworkId
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisCreateCmd = runGenesisCreateCmd

runLegacyGenesisCreateCardanoCmd :: ()
  => GenesisDir
  -> Word  -- ^ num genesis & delegate keys to make
  -> Word  -- ^ num utxo keys to make
  -> Maybe SystemStart
  -> Maybe Lovelace
  -> BlockCount
  -> Word     -- ^ slot length in ms
  -> Rational
  -> NetworkId
  -> FilePath -- ^ Byron Genesis
  -> FilePath -- ^ Shelley Genesis
  -> FilePath -- ^ Alonzo Genesis
  -> FilePath -- ^ Conway Genesis
  -> Maybe FilePath
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisCreateCardanoCmd = runGenesisCreateCardanoCmd

runLegacyGenesisCreateStakedCmd :: ()
  => KeyOutputFormat    -- ^ key output format
  -> GenesisDir
  -> Word               -- ^ num genesis & delegate keys to make
  -> Word               -- ^ num utxo keys to make
  -> Word               -- ^ num pools to make
  -> Word               -- ^ num delegators to make
  -> Maybe SystemStart
  -> Maybe Lovelace     -- ^ supply going to non-delegators
  -> Lovelace           -- ^ supply going to delegators
  -> NetworkId
  -> Word               -- ^ bulk credential files to write
  -> Word               -- ^ pool credentials per bulk file
  -> Word               -- ^ num stuffed UTxO entries
  -> Maybe FilePath     -- ^ Specified stake pool relays
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisCreateStakedCmd = runGenesisCreateStakedCmd

-- | Hash a genesis file
runLegacyGenesisHashFileCmd :: ()
  => GenesisFile
  -> ExceptT ShelleyGenesisCmdError IO ()
runLegacyGenesisHashFileCmd = runGenesisHashFileCmd