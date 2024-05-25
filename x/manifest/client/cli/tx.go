package cli

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/client/tx"
	sdk "github.com/cosmos/cosmos-sdk/types"

	"github.com/liftedinit/manifest-ledger/x/manifest/types"
)

// NewTxCmd returns a root CLI command handler for certain modules
// transaction commands.
func NewTxCmd() *cobra.Command {
	txCmd := &cobra.Command{
		Use:                        types.ModuleName,
		Short:                      types.ModuleName + " subcommands.",
		DisableFlagParsing:         true,
		SuggestionsMinimumDistance: 2,
		RunE:                       client.ValidateCmd,
	}

	txCmd.AddCommand(
		MsgBurnCoins(),
		MsgUpdateParams(),
		MsgDeployStakeholderPayout(),
	)
	return txCmd
}

// MsgUpdateParams returns a CLI command handler for updating the params.
func MsgUpdateParams() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "update-params [address_pairs] [automatic_inflation_enabled] [inflation_per_year]",
		Short:   "Update the params (authority only)",
		Example: `update-params address:1_000_000,address2:99_000_000 true 500000000umfx`,
		Args:    cobra.ExactArgs(3),
		RunE: func(cmd *cobra.Command, args []string) error {
			cliCtx, err := client.GetClientTxContext(cmd)
			if err != nil {
				return err
			}

			sender := cliCtx.GetFromAddress()

			sh, err := fromStrToStakeholders(args[0])
			if err != nil {
				return err
			}

			isInflationEnabled, err := strconv.ParseBool(args[1])
			if err != nil {
				return err
			}

			coin, err := sdk.ParseCoinNormalized(args[2])
			if err != nil {
				return err
			}

			msg := &types.MsgUpdateParams{
				Authority: sender.String(),
				Params:    types.NewParams(sh, isInflationEnabled, coin.Amount.Uint64(), coin.Denom),
			}

			if err := msg.Validate(); err != nil {
				return err
			}

			return tx.GenerateOrBroadcastTxCLI(cliCtx, cmd.Flags(), msg)
		},
	}

	flags.AddTxFlagsToCmd(cmd)
	return cmd
}

// MsgDeployStakeholderPayout returns a CLI command handler for deploying a stakeholder payout (where stakeholders are set in the current params).
func MsgDeployStakeholderPayout() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "stakeholder-payout [coin_amount]",
		Short:   "Payout current stakeholders (authority)",
		Example: `stakeholder-payout 50000umfx`,
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			cliCtx, err := client.GetClientTxContext(cmd)
			if err != nil {
				return err
			}

			authority := cliCtx.GetFromAddress()

			coin, err := sdk.ParseCoinNormalized(args[0])
			if err != nil {
				return err
			}

			msg := &types.MsgPayoutStakeholders{
				Authority: authority.String(),
				Payout:    coin,
			}

			if err := msg.Validate(); err != nil {
				return err
			}

			return tx.GenerateOrBroadcastTxCLI(cliCtx, cmd.Flags(), msg)
		},
	}

	flags.AddTxFlagsToCmd(cmd)
	return cmd
}

// MsgBurnCoins returns a CLI command handler for burning held coins.
func MsgBurnCoins() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "burn-coins [coins]",
		Short:   "Burn held coins",
		Example: `burn-coins 50000umfx,100other`,
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			cliCtx, err := client.GetClientTxContext(cmd)
			if err != nil {
				return err
			}

			sender := cliCtx.GetFromAddress()

			coins, err := sdk.ParseCoinsNormalized(args[0])
			if err != nil {
				return err
			}

			msg := &types.MsgBurnHeldBalance{
				Sender:    sender.String(),
				BurnCoins: coins,
			}

			if err := msg.Validate(); err != nil {
				return err
			}

			return tx.GenerateOrBroadcastTxCLI(cliCtx, cmd.Flags(), msg)
		},
	}

	flags.AddTxFlagsToCmd(cmd)
	return cmd
}

// fromStrToStakeholders converts a string to a slice of StakeHolders.
// ex: address:1_000_000,address2:99_000_000
func fromStrToStakeholders(s string) ([]*types.StakeHolders, error) {
	stakeHolders := make([]*types.StakeHolders, 0)

	s = strings.ReplaceAll(s, "_", "")

	for _, stakeholder := range strings.Split(s, ",") {
		parts := strings.Split(stakeholder, ":")
		if len(parts) != 2 {
			return nil, fmt.Errorf("invalid stakeholder: %s", stakeholder)
		}

		percentage, err := strconv.ParseInt(parts[1], 10, 32)
		if err != nil {
			return nil, fmt.Errorf("invalid percentage: %s", parts[1])
		}

		_, err = sdk.AccAddressFromBech32(parts[0])
		if err != nil {
			return nil, fmt.Errorf("invalid address: %s", parts[0])
		}

		sh := &types.StakeHolders{
			Address:    parts[0],
			Percentage: int32(percentage),
		}

		stakeHolders = append(stakeHolders, sh)
	}

	return stakeHolders, nil
}
