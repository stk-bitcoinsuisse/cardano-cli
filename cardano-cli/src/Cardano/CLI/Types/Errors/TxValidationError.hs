{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Cardano.CLI.Types.Errors.TxValidationError
  ( TxAuxScriptsValidationError(..)
  , TxGovDuplicateVotes(..)
  , TxNotSupportedInAnyCardanoEraValidationError(..)
  , convToTxProposalProcedures
  , convertToTxVotingProcedures
  , validateScriptSupportedInEra
  , validateTxAuxScripts
  , validateRequiredSigners
  , validateTxReturnCollateral
  , validateTxScriptValidity
  , validateTxTotalCollateral
  , validateTxValidityLowerBound
  , validateUpdateProposalFile
  ) where

import           Cardano.Api
import qualified Cardano.Api.Ledger as L
import           Cardano.Api.Shelley

import           Cardano.CLI.Types.Common

import           Prelude

import           Control.Monad (foldM)
import           Data.Bifunctor (first)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Maybe
import qualified Data.OSet.Strict as OSet
import qualified Data.Text as T
import           Prettyprinter (viaShow)

data ScriptLanguageValidationError
  = ScriptLanguageValidationError AnyScriptLanguage AnyCardanoEra
  deriving Show

instance Error ScriptLanguageValidationError where
  prettyError = \case
    ScriptLanguageValidationError lang era ->
      "The script language " <> pshow lang <> " is not supported in the " <>
      pretty era <> " era."

validateScriptSupportedInEra
  :: ShelleyBasedEra era
  -> ScriptInAnyLang
  -> Either ScriptLanguageValidationError (ScriptInEra era)
validateScriptSupportedInEra era script@(ScriptInAnyLang lang _) =
  case toScriptInEra era script of
    Nothing -> Left $ ScriptLanguageValidationError
                        (AnyScriptLanguage lang) (anyCardanoEra $ toCardanoEra era)
    Just script' -> pure script'

data TxNotSupportedInAnyCardanoEraValidationError era =
    -- | First argument is the kind of data that is not supported.
    -- Second argument is the era that doesn't support the data.
    TxNotSupportedInAnyCardanoEraValidationError T.Text AnyCardanoEra

instance Show (TxNotSupportedInAnyCardanoEraValidationError era) where
  show (TxNotSupportedInAnyCardanoEraValidationError a era) =
    show (pretty a) <> " not supported in " <> show era

instance Error (TxNotSupportedInAnyCardanoEraValidationError era) where
  prettyError (TxNotSupportedInAnyCardanoEraValidationError a era) =
    pretty a <+> "not supported in" <+> viaShow era

validateTxTotalCollateral :: ShelleyBasedEra era
                          -> Maybe L.Coin
                          -> Either (TxNotSupportedInAnyCardanoEraValidationError era) (TxTotalCollateral era)
validateTxTotalCollateral _ Nothing = return TxTotalCollateralNone
validateTxTotalCollateral sbe (Just coll) = do
  supported <- conjureWitness (toCardanoEra sbe) $ TxNotSupportedInAnyCardanoEraValidationError "Transaction collateral"
  pure $ TxTotalCollateral supported coll

validateTxReturnCollateral :: ShelleyBasedEra era
                           -> Maybe (TxOut CtxTx era)
                           -> Either (TxNotSupportedInAnyCardanoEraValidationError era) (TxReturnCollateral CtxTx era)
validateTxReturnCollateral _ Nothing = return TxReturnCollateralNone
validateTxReturnCollateral sbe (Just retColTxOut) = do
  supported <- conjureWitness (toCardanoEra sbe) $ TxNotSupportedInAnyCardanoEraValidationError "Transaction return collateral"
  pure $ TxReturnCollateral supported retColTxOut

validateTxValidityLowerBound :: ShelleyBasedEra era
                             -> Maybe SlotNo
                             -> Either (TxNotSupportedInAnyCardanoEraValidationError era) (TxValidityLowerBound era)
validateTxValidityLowerBound _ Nothing = return TxValidityNoLowerBound
validateTxValidityLowerBound sbe (Just slot) = do
  supported <- conjureWitness (toCardanoEra sbe) $ TxNotSupportedInAnyCardanoEraValidationError "Transaction validity lower bound"
  pure $ TxValidityLowerBound supported slot

data TxAuxScriptsValidationError
  = TxAuxScriptsNotSupportedInEra AnyCardanoEra
  | TxAuxScriptsLanguageError ScriptLanguageValidationError
  deriving Show

instance Error TxAuxScriptsValidationError where
  prettyError (TxAuxScriptsNotSupportedInEra era) =
    "Transaction auxiliary scripts are not supported in " <> pretty era
  prettyError (TxAuxScriptsLanguageError e) =
    "Transaction auxiliary scripts error: " <> prettyError e

validateTxAuxScripts
  :: ShelleyBasedEra era
  -> [ScriptInAnyLang]
  -> Either TxAuxScriptsValidationError (TxAuxScripts era)
validateTxAuxScripts _ [] = return TxAuxScriptsNone
validateTxAuxScripts era scripts = do
  supported <- conjureWitness (toCardanoEra era) TxAuxScriptsNotSupportedInEra
  scriptsInEra <- mapM (first TxAuxScriptsLanguageError . validateScriptSupportedInEra era) scripts
  pure $ TxAuxScripts supported scriptsInEra

validateRequiredSigners
  :: ShelleyBasedEra era
  -> [Hash PaymentKey]
  -> Either (TxNotSupportedInAnyCardanoEraValidationError era) (TxExtraKeyWitnesses era)
validateRequiredSigners _ [] = return TxExtraKeyWitnessesNone
validateRequiredSigners sbe reqSigs = do
  supported <- conjureWitness (toCardanoEra sbe) $ TxNotSupportedInAnyCardanoEraValidationError "Transaction required signers"
  pure $ TxExtraKeyWitnesses supported reqSigs

validateTxScriptValidity
  :: ShelleyBasedEra era
  -> Maybe ScriptValidity
  -> Either (TxNotSupportedInAnyCardanoEraValidationError era) (TxScriptValidity era)
validateTxScriptValidity _ Nothing = pure TxScriptValidityNone
validateTxScriptValidity sbe (Just scriptValidity) = do
  supported <- conjureWitness (toCardanoEra sbe) $ TxNotSupportedInAnyCardanoEraValidationError "Transaction script validity"
  pure $ TxScriptValidity supported scriptValidity

-- TODO legacy. This can be deleted when legacy commands are removed.
validateUpdateProposalFile
  :: CardanoEra era
  -> Maybe UpdateProposalFile
  -> Either (TxNotSupportedInAnyCardanoEraValidationError era) (Maybe (Featured ShelleyToBabbageEra era (Maybe UpdateProposalFile)))
validateUpdateProposalFile era = \case
  Nothing -> pure Nothing
  Just updateProposal -> do
    supported <- conjureWitness era $ TxNotSupportedInAnyCardanoEraValidationError "Transaction update proposal"
    pure $ Just $ Featured supported $ Just updateProposal

-- TODO make this function take a ShelleyBasedEra when the last
-- CardanoEra caller is removed (there remains only one).
conjureWitness :: Eon eon
               => CardanoEra era -- ^ era to try to conjure eon from
               -> (AnyCardanoEra -> e)  -- ^ error wrapper function
               -> Either e (eon era) -- ^ eon if it includes the era, an error otherwise
conjureWitness era errF =
  maybe (cardanoEraConstraints era $ Left . errF $ AnyCardanoEra era) Right $
    forEraMaybeEon era

getVotingScriptCredentials
  :: VotingProcedures era
  -> Maybe (L.Voter (L.EraCrypto (ShelleyLedgerEra era)))
getVotingScriptCredentials (VotingProcedures (L.VotingProcedures m)) =
  listToMaybe $ Map.keys m

votingScriptWitnessSingleton
  :: VotingProcedures era
  -> Maybe (ScriptWitness WitCtxStake era)
  -> Map (L.Voter (L.EraCrypto (ShelleyLedgerEra era))) (ScriptWitness WitCtxStake era)
votingScriptWitnessSingleton _ Nothing = Map.empty
votingScriptWitnessSingleton votingProcedures (Just scriptWitness) =
  let voter = fromJust $ getVotingScriptCredentials votingProcedures
  in Map.singleton voter scriptWitness

newtype TxGovDuplicateVotes era =
  TxGovDuplicateVotes (VotesMergingConflict era)

instance Error (TxGovDuplicateVotes era) where
  prettyError (TxGovDuplicateVotes (VotesMergingConflict (_voter, actionIds))) =
    "Trying to merge votes with similar action identifiers: " <> viaShow actionIds <>
      ". This would cause ignoring some of the votes, so not proceeding."

-- TODO: We fold twice, we can do it in a single fold
convertToTxVotingProcedures
 :: [(VotingProcedures era, Maybe (ScriptWitness WitCtxStake era))]
 -> Either (TxGovDuplicateVotes era) (TxVotingProcedures BuildTx era)
convertToTxVotingProcedures votingProcedures = do
  VotingProcedures procedure <- first TxGovDuplicateVotes $
    foldM f emptyVotingProcedures votingProcedures
  pure $ TxVotingProcedures procedure (BuildTxWith votingScriptWitnessMap)
  where
    votingScriptWitnessMap = foldl (\acc next -> acc `Map.union` uncurry votingScriptWitnessSingleton next)
                               Map.empty
                               votingProcedures
    f acc (procedure, _witness) = mergeVotingProcedures acc procedure

proposingScriptWitnessSingleton
  :: Proposal era
  -> Maybe (ScriptWitness WitCtxStake era)
  -> Map (L.ProposalProcedure (ShelleyLedgerEra era)) (ScriptWitness WitCtxStake era)
proposingScriptWitnessSingleton _ Nothing = Map.empty
proposingScriptWitnessSingleton (Proposal proposalProcedure) (Just scriptWitness) =
  Map.singleton proposalProcedure scriptWitness

convToTxProposalProcedures
  :: L.EraPParams (ShelleyLedgerEra era)
  => [(Proposal era, Maybe (ScriptWitness WitCtxStake era))]
  -> TxProposalProcedures BuildTx era
convToTxProposalProcedures proposalProcedures =
   -- TODO: Ledger does not export snoc so we can't fold here.
   let proposals = OSet.fromFoldable $ map (unProposal . fst) proposalProcedures
       sWitMap = BuildTxWith $ foldl sWitMapFolder Map.empty proposalProcedures
   in TxProposalProcedures proposals sWitMap
  where
   sWitMapFolder sWitMapAccum nextSWit = sWitMapAccum `Map.union` uncurry proposingScriptWitnessSingleton nextSWit

