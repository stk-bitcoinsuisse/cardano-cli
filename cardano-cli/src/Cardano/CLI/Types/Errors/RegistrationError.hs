{-# LANGUAGE LambdaCase #-}

module Cardano.CLI.Types.Errors.RegistrationError
  ( RegistrationError (..)
  )
where

import           Cardano.Api
import qualified Cardano.Api.Ledger as L

import           Cardano.CLI.Types.Errors.HashCmdError (FetchURLError)
import           Cardano.CLI.Types.Errors.StakeAddressRegistrationError
import           Cardano.CLI.Types.Errors.StakeCredentialError

import           Control.Exception (displayException)

data RegistrationError
  = RegistrationReadError !(FileError InputDecodeError)
  | RegistrationWriteFileError !(FileError ())
  | RegistrationStakeCredentialError !StakeCredentialError
  | RegistrationStakeError !StakeAddressRegistrationError
  | RegistrationMismatchedDRepMetadataHashError
      !(L.SafeHash L.StandardCrypto L.AnchorData)
      !(L.SafeHash L.StandardCrypto L.AnchorData)
  | RegistrationFetchURLError !FetchURLError
  deriving Show

instance Error RegistrationError where
  prettyError = \case
    RegistrationReadError e ->
      "Cannot read registration certificate: " <> prettyError e
    RegistrationWriteFileError e ->
      "Cannot write registration certificate: " <> prettyError e
    RegistrationStakeCredentialError e ->
      "Cannot read stake credential: " <> prettyError e
    RegistrationStakeError e ->
      "Stake address registation error: " <> prettyError e
    RegistrationMismatchedDRepMetadataHashError expectedHash actualHash ->
      "DRep metadata Hashes do not match!"
        <> "\nExpected:"
          <+> pretty (show (L.extractHash expectedHash))
        <> "\n  Actual:"
          <+> pretty (show (L.extractHash actualHash))
    RegistrationFetchURLError fetchErr ->
      "Error while fetching proposal: " <> pretty (displayException fetchErr)
