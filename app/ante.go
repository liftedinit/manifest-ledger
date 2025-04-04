package app

import (
	"errors"

	"github.com/cosmos/ibc-go/v8/modules/apps/transfer/types"
	ibcante "github.com/cosmos/ibc-go/v8/modules/core/ante"
	"github.com/cosmos/ibc-go/v8/modules/core/keeper"

	corestoretypes "cosmossdk.io/core/store"
	sdkmath "cosmossdk.io/math"
	circuitante "cosmossdk.io/x/circuit/ante"
	circuitkeeper "cosmossdk.io/x/circuit/keeper"

	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/x/auth/ante"

	poaante "github.com/strangelove-ventures/poa/ante"

	wasmkeeper "github.com/CosmWasm/wasmd/x/wasm/keeper"
	wasmtypes "github.com/CosmWasm/wasmd/x/wasm/types"

	"github.com/liftedinit/manifest-ledger/app/decorators"
)

type RateMinMax struct {
	Floor sdkmath.LegacyDec
	Ceil  sdkmath.LegacyDec
}

// HandlerOptions extend the SDK's AnteHandler options by requiring the IBC
// channel keeper.
type HandlerOptions struct {
	ante.HandlerOptions

	IBCKeeper         *keeper.Keeper
	CircuitKeeper     *circuitkeeper.Keeper
	RateMinMax        RateMinMax
	WasmKeeper        *wasmkeeper.Keeper
	WasmConfig        *wasmtypes.NodeConfig
	TxCounterStoreKey corestoretypes.KVStoreService
}

func NewAnteHandler(options HandlerOptions) (sdk.AnteHandler, error) {
	if options.AccountKeeper == nil {
		return nil, errors.New("account keeper is required for ante builder")
	}
	if options.BankKeeper == nil {
		return nil, errors.New("bank keeper is required for ante builder")
	}
	if options.SignModeHandler == nil {
		return nil, errors.New("sign mode handler is required for ante builder")
	}
	if options.CircuitKeeper == nil {
		return nil, errors.New("circuit keeper is required for ante builder")
	}
	if options.RateMinMax.Floor.IsNil() {
		return nil, errors.New("rate floor is required for ante builder")
	}
	if options.RateMinMax.Ceil.IsNil() {
		return nil, errors.New("rate ceil is required for ante builder")
	}
	if options.RateMinMax.Floor.IsNegative() {
		return nil, errors.New("rate floor must be non-negative")
	}
	if options.RateMinMax.Ceil.IsNegative() {
		return nil, errors.New("rate ceil must be non-negative")
	}

	doGenTxRateValidation := false

	anteDecorators := []sdk.AnteDecorator{
		ante.NewSetUpContextDecorator(),
		wasmkeeper.NewLimitSimulationGasDecorator(options.WasmConfig.SimulationGasLimit),
		wasmkeeper.NewCountTXDecorator(options.TxCounterStoreKey),
		wasmkeeper.NewGasRegisterDecorator(options.WasmKeeper.GetGasRegister()),
		wasmkeeper.NewTxContractsDecorator(),
		circuitante.NewCircuitBreakerDecorator(options.CircuitKeeper),
		ante.NewExtensionOptionsDecorator(options.ExtensionOptionChecker),
		ante.NewValidateBasicDecorator(),
		ante.NewTxTimeoutHeightDecorator(),
		ante.NewValidateMemoDecorator(options.AccountKeeper),
		ante.NewConsumeGasForTxSizeDecorator(options.AccountKeeper),
		ante.NewDeductFeeDecorator(options.AccountKeeper, options.BankKeeper, options.FeegrantKeeper, options.TxFeeChecker),
		ante.NewSetPubKeyDecorator(options.AccountKeeper), // SetPubKeyDecorator must be called before all signature verification decorators
		ante.NewValidateSigCountDecorator(options.AccountKeeper),
		ante.NewSigGasConsumeDecorator(options.AccountKeeper, options.SigGasConsumer),
		ante.NewSigVerificationDecorator(options.AccountKeeper, options.SignModeHandler),
		ante.NewIncrementSequenceDecorator(options.AccountKeeper),
		poaante.NewPOADisableStakingDecorator(),
		poaante.NewPOADisableWithdrawDelegatorRewards(),
		poaante.NewCommissionLimitDecorator(doGenTxRateValidation, options.RateMinMax.Floor, options.RateMinMax.Ceil),
		ibcante.NewRedundantRelayDecorator(options.IBCKeeper),
		decorators.FilterDecorator(&types.MsgTransfer{}), // TODO: Remove this when we allow IBC transfers
	}

	return sdk.ChainAnteDecorators(anteDecorators...), nil
}
