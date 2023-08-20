{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}

module Cardano.CLI.Legacy.Run.Pool
  ( runPoolCmds
  ) where

import           Cardano.Api
import qualified Cardano.Api.Ledger as Ledger
import           Cardano.Api.Shelley

import           Cardano.CLI.Legacy.Commands.Pool
import           Cardano.CLI.Types.Common
import           Cardano.CLI.Types.Errors.ShelleyPoolCmdError
import           Cardano.CLI.Types.Key (VerificationKeyOrFile, readVerificationKeyOrFile)
import qualified Cardano.Ledger.Slot as Shelley

import           Control.Monad.IO.Class (MonadIO (..))
import           Control.Monad.Trans (lift)
import           Control.Monad.Trans.Except (ExceptT)
import           Control.Monad.Trans.Except.Extra (firstExceptT, handleIOExceptT, hoistEither, left,
                   newExceptT, onLeft)
import qualified Data.ByteString.Char8 as BS
import           Data.Function ((&))

runPoolCmds :: LegacyPoolCmds -> ExceptT ShelleyPoolCmdError IO ()
runPoolCmds = \case
  PoolRegistrationCert anyEra sPvkey vrfVkey pldg pCost pMrgn rwdVerFp ownerVerFps relays mbMetadata network outfp ->
    runStakePoolRegistrationCert anyEra sPvkey vrfVkey pldg pCost pMrgn rwdVerFp ownerVerFps relays mbMetadata network outfp
  PoolRetirementCert anyEra sPvkeyFp retireEpoch outfp ->
    runStakePoolRetirementCert anyEra sPvkeyFp retireEpoch outfp
  PoolGetId sPvkey outputFormat mOutFile ->
    runPoolId sPvkey outputFormat mOutFile
  PoolMetadataHash poolMdFile mOutFile ->
    runPoolMetadataHash poolMdFile mOutFile

--
-- Stake pool command implementations
--

-- | Create a stake pool registration cert.
-- TODO: Metadata and more stake pool relay support to be
-- added in the future.
runStakePoolRegistrationCert
  :: AnyShelleyBasedEra
  -> VerificationKeyOrFile StakePoolKey
  -- ^ Stake pool verification key.
  -> VerificationKeyOrFile VrfKey
  -- ^ VRF Verification key.
  -> Lovelace
  -- ^ Pool pledge.
  -> Lovelace
  -- ^ Pool cost.
  -> Rational
  -- ^ Pool margin.
  -> VerificationKeyOrFile StakeKey
  -- ^ Stake verification key for reward account.
  -> [VerificationKeyOrFile StakeKey]
  -- ^ Pool owner stake verification key(s).
  -> [StakePoolRelay]
  -- ^ Stake pool relays.
  -> Maybe StakePoolMetadataReference
  -- ^ Stake pool metadata.
  -> NetworkId
  -> File () Out
  -> ExceptT ShelleyPoolCmdError IO ()
runStakePoolRegistrationCert
  anyEra
  stakePoolVerKeyOrFile
  vrfVerKeyOrFile
  pldg
  pCost
  pMrgn
  rwdStakeVerKeyOrFile
  ownerStakeVerKeyOrFiles
  relays
  mbMetadata
  network
  outfp = do
    AnyShelleyBasedEra sbe <- pure anyEra

    -- Pool verification key
    stakePoolVerKey <- firstExceptT ShelleyPoolCmdReadKeyFileError
      . newExceptT
      $ readVerificationKeyOrFile AsStakePoolKey stakePoolVerKeyOrFile
    let stakePoolId' = verificationKeyHash stakePoolVerKey

    -- VRF verification key
    vrfVerKey <- firstExceptT ShelleyPoolCmdReadKeyFileError
      . newExceptT
      $ readVerificationKeyOrFile AsVrfKey vrfVerKeyOrFile
    let vrfKeyHash' = verificationKeyHash vrfVerKey

    -- Pool reward account
    rwdStakeVerKey <- firstExceptT ShelleyPoolCmdReadKeyFileError
      . newExceptT
      $ readVerificationKeyOrFile AsStakeKey rwdStakeVerKeyOrFile
    let stakeCred = StakeCredentialByKey (verificationKeyHash rwdStakeVerKey)
        rewardAccountAddr = makeStakeAddress network stakeCred

    -- Pool owner(s)
    sPoolOwnerVkeys <-
      mapM
        (firstExceptT ShelleyPoolCmdReadKeyFileError
          . newExceptT
          . readVerificationKeyOrFile AsStakeKey
        )
        ownerStakeVerKeyOrFiles
    let stakePoolOwners' = map verificationKeyHash sPoolOwnerVkeys

    let stakePoolParams =
          StakePoolParameters
            { stakePoolId = stakePoolId'
            , stakePoolVRF = vrfKeyHash'
            , stakePoolCost = pCost
            , stakePoolMargin = pMrgn
            , stakePoolRewardAccount = rewardAccountAddr
            , stakePoolPledge = pldg
            , stakePoolOwners = stakePoolOwners'
            , stakePoolRelays = relays
            , stakePoolMetadata = mbMetadata
            }

    let ledgerStakePoolParams = toShelleyPoolParams stakePoolParams
        req = createStakePoolRegistrationRequirements sbe
          $ shelleyBasedEraConstraints sbe ledgerStakePoolParams
        registrationCert = makeStakePoolRegistrationCertificate req

    firstExceptT ShelleyPoolCmdWriteFileError
      . newExceptT
      $ writeLazyByteStringFile outfp
      $ textEnvelopeToJSON (Just registrationCertDesc) registrationCert
  where
    registrationCertDesc :: TextEnvelopeDescr
    registrationCertDesc = "Stake Pool Registration Certificate"

createStakePoolRegistrationRequirements
  :: ShelleyBasedEra era
  -> Ledger.PoolParams (Ledger.EraCrypto (ShelleyLedgerEra era))
  -> StakePoolRegistrationRequirements era
createStakePoolRegistrationRequirements sbe pparams =
 case sbe of
   ShelleyBasedEraShelley ->
     StakePoolRegistrationRequirementsPreConway ShelleyToBabbageEraShelley pparams
   ShelleyBasedEraAllegra ->
     StakePoolRegistrationRequirementsPreConway ShelleyToBabbageEraAllegra pparams
   ShelleyBasedEraMary ->
     StakePoolRegistrationRequirementsPreConway ShelleyToBabbageEraMary pparams
   ShelleyBasedEraAlonzo ->
     StakePoolRegistrationRequirementsPreConway ShelleyToBabbageEraAlonzo pparams
   ShelleyBasedEraBabbage ->
     StakePoolRegistrationRequirementsPreConway ShelleyToBabbageEraBabbage pparams
   ShelleyBasedEraConway ->
     StakePoolRegistrationRequirementsConwayOnwards ConwayEraOnwardsConway pparams


runStakePoolRetirementCert
  :: AnyShelleyBasedEra
  -> VerificationKeyOrFile StakePoolKey
  -> Shelley.EpochNo
  -> File () Out
  -> ExceptT ShelleyPoolCmdError IO ()
runStakePoolRetirementCert anyEra stakePoolVerKeyOrFile retireEpoch outfp = do
    AnyShelleyBasedEra sbe <- pure anyEra

    -- Pool verification key
    stakePoolVerKey <- firstExceptT ShelleyPoolCmdReadKeyFileError
      . newExceptT
      $ readVerificationKeyOrFile AsStakePoolKey stakePoolVerKeyOrFile

    let stakePoolId' = verificationKeyHash stakePoolVerKey
        req = createStakePoolRetirementRequirements sbe stakePoolId' retireEpoch
        retireCert = makeStakePoolRetirementCertificate req

    firstExceptT ShelleyPoolCmdWriteFileError
      . newExceptT
      $ writeLazyByteStringFile outfp
      $ textEnvelopeToJSON (Just retireCertDesc) retireCert
  where
    retireCertDesc :: TextEnvelopeDescr
    retireCertDesc = "Stake Pool Retirement Certificate"

createStakePoolRetirementRequirements
  :: ShelleyBasedEra era
  -> PoolId
  -> Ledger.EpochNo
  -> StakePoolRetirementRequirements era
createStakePoolRetirementRequirements sbe pid epoch =
  case sbe of
    ShelleyBasedEraShelley ->
      StakePoolRetirementRequirementsPreConway ShelleyToBabbageEraShelley pid epoch
    ShelleyBasedEraAllegra ->
      StakePoolRetirementRequirementsPreConway ShelleyToBabbageEraAllegra pid epoch
    ShelleyBasedEraMary ->
      StakePoolRetirementRequirementsPreConway ShelleyToBabbageEraMary pid epoch
    ShelleyBasedEraAlonzo ->
      StakePoolRetirementRequirementsPreConway ShelleyToBabbageEraAlonzo pid epoch
    ShelleyBasedEraBabbage ->
      StakePoolRetirementRequirementsPreConway ShelleyToBabbageEraBabbage pid epoch
    ShelleyBasedEraConway ->
      StakePoolRetirementRequirementsConwayOnwards ConwayEraOnwardsConway pid epoch


runPoolId
  :: VerificationKeyOrFile StakePoolKey
  -> PoolIdOutputFormat
  -> Maybe (File () Out)
  -> ExceptT ShelleyPoolCmdError IO ()
runPoolId verKeyOrFile outputFormat mOutFile = do
  stakePoolVerKey <- firstExceptT ShelleyPoolCmdReadKeyFileError
    . newExceptT
    $ readVerificationKeyOrFile AsStakePoolKey verKeyOrFile

  case outputFormat of
    PoolIdOutputFormatHex ->
      firstExceptT ShelleyPoolCmdWriteFileError
        . newExceptT
        $ writeByteStringOutput mOutFile
        $ serialiseToRawBytesHex (verificationKeyHash stakePoolVerKey)
    PoolIdOutputFormatBech32 ->
      firstExceptT ShelleyPoolCmdWriteFileError
        . newExceptT
        $ writeTextOutput mOutFile
        $ serialiseToBech32 (verificationKeyHash stakePoolVerKey)

runPoolMetadataHash :: StakePoolMetadataFile In -> Maybe (File () Out) -> ExceptT ShelleyPoolCmdError IO ()
runPoolMetadataHash poolMDPath mOutFile = do
  metadataBytes <- lift (readByteStringFile poolMDPath)
    & onLeft (left . ShelleyPoolCmdReadFileError)

  (_metadata, metadataHash) <-
      firstExceptT ShelleyPoolCmdMetadataValidationError
    . hoistEither
    $ validateAndHashStakePoolMetadata metadataBytes
  case mOutFile of
    Nothing -> liftIO $ BS.putStrLn (serialiseToRawBytesHex metadataHash)
    Just (File fpath) ->
      handleIOExceptT (ShelleyPoolCmdWriteFileError . FileIOError fpath)
        $ BS.writeFile fpath (serialiseToRawBytesHex metadataHash)
