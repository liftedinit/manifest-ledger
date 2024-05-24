package types

import (
	"cosmossdk.io/errors"
)

var (
	ErrManualMintingDisabled = errors.Register(ModuleName, 1, "manual minting is disabled due to automatic inflation being on")
	ErrInflationParamsNotSet = errors.Register(ModuleName, 2, "inflation params not set")
)
