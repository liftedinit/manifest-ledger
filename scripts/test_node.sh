#!/bin/bash
# Run this script to quickly install, setup, and run the current chain without docker.
#
# Example:
# POA_ADMIN_ADDRESS=manifest1hj5fveer5cjtn4wd6wstzugjfdxzl0xp8ws9ct CHAIN_ID="local-1" HOME_DIR="~/.manifest" TIMEOUT_COMMIT="500ms" CLEAN=true sh scripts/test_node.sh
# CHAIN_ID="local-2" HOME_DIR="~/.manifest2" CLEAN=true RPC=36657 REST=2317 PROFF=6061 P2P=36656 GRPC=8090 GRPC_WEB=8091 ROSETTA=8081 TIMEOUT_COMMIT="500ms" sh scripts/test_node.sh
#
# To use unoptomized wasm files up to ~5mb, add: MAX_WASM_SIZE=5000000

export KEY="user1"
export KEY2="user2"

export CHAIN_ID=${CHAIN_ID:-"local-1"}
export MONIKER="localval"
export KEYALGO="secp256k1"
export KEYRING=${KEYRING:-"test"}
export HOME_DIR=$(eval echo "${HOME_DIR:-"~/.manifest"}")
export BINARY=${BINARY:-manifestd}

export CLEAN=${CLEAN:-"false"}
export RPC=${RPC:-"26657"}
export REST=${REST:-"1317"}
export PROFF=${PROFF:-"6060"}
export P2P=${P2P:-"26656"}
export GRPC=${GRPC:-"9090"}
export GRPC_WEB=${GRPC_WEB:-"9091"}
export ROSETTA=${ROSETTA:-"8080"}
export TIMEOUT_COMMIT=${TIMEOUT_COMMIT:-"5s"}

alias BINARY="$BINARY --home=$HOME_DIR"

command -v $BINARY > /dev/null 2>&1 || { echo >&2 "$BINARY command not found. Ensure this is setup / properly installed in your GOPATH (make install)."; exit 1; }
command -v jq > /dev/null 2>&1 || { echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"; exit 1; }

$BINARY config set client chain-id $CHAIN_ID
$BINARY config set client keyring-backend $KEYRING

from_scratch () {
  # Fresh install on current branch
  make install

  # remove existing daemon.
  rm -rf $HOME_DIR && echo "Removed $HOME_DIR"

  # manifest1hj5fveer5cjtn4wd6wstzugjfdxzl0xp8ws9ct
  echo "decorate bright ozone fork gallery riot bus exhaust worth way bone indoor calm squirrel merry zero scheme cotton until shop any excess stage laundry" | BINARY keys add $KEY --keyring-backend $KEYRING --algo $KEYALGO --recover
  # manifest1efd63aw40lxf3n4mhf7dzhjkr453axurm6rp3z
  echo "wealth flavor believe regret funny network recall kiss grape useless pepper cram hint member few certain unveil rather brick bargain curious require crowd raise" | BINARY keys add $KEY2 --keyring-backend $KEYRING --algo $KEYALGO --recover

  BINARY init $MONIKER --chain-id $CHAIN_ID --default-denom=umfx

  # Function updates the config based on a jq argument as a string
  update_test_genesis () {
    cat $HOME_DIR/config/genesis.json | jq "$1" > $HOME_DIR/config/tmp_genesis.json && mv $HOME_DIR/config/tmp_genesis.json $HOME_DIR/config/genesis.json
  }

  # Block
  update_test_genesis '.consensus_params["block"]["max_gas"]="1000000000"'
  # Gov
  update_test_genesis '.app_state["gov"]["params"]["min_deposit"]=[{"denom": "umfx","amount": "1000000"}]'
  update_test_genesis '.app_state["gov"]["params"]["voting_period"]="15s"'
  update_test_genesis '.app_state["gov"]["params"]["expedited_voting_period"]="10s"'
  # staking
  update_test_genesis '.app_state["staking"]["params"]["bond_denom"]="ustake"' # PoA Token
  update_test_genesis '.app_state["staking"]["params"]["min_commission_rate"]="0.000000000000000000"'
  # mint
  update_test_genesis '.app_state["mint"]["params"]["mint_denom"]="umfx"' # not used
  update_test_genesis '.app_state["mint"]["params"]["blocks_per_year"]="6311520"'

  # Custom Modules

  # TokenFactory
  update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_fee"]=[]'
  update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_gas_consume"]=2000000'

  # manifest
  update_test_genesis '.app_state["manifest"]["params"]["inflation"]["mint_denom"]="umfx"'
  update_test_genesis '.app_state["manifest"]["params"]["inflation"]["yearly_amount"]="500000000000"' # in micro format (1MFX = 10**6)
  update_test_genesis '.app_state["manifest"]["params"]["inflation"]["automatic_enabled"]=true'
  update_test_genesis '.app_state["manifest"]["params"]["stake_holders"]=[{"address":"manifest1hj5fveer5cjtn4wd6wstzugjfdxzl0xp8ws9ct","percentage":100000000}]'

  # Allocate genesis accounts
  BINARY genesis add-genesis-account $KEY 1000000ustake,10000000umfx,1000utest --keyring-backend $KEYRING
  BINARY genesis add-genesis-account $KEY2 100000umfx,1000utest --keyring-backend $KEYRING

  # Set 1 POAToken -> user
  GenTxFlags="--commission-rate=0.0 --commission-max-rate=1.0 --commission-max-change-rate=0.1"
  BINARY genesis gentx $KEY 1000000ustake --keyring-backend $KEYRING --chain-id $CHAIN_ID $GenTxFlags

  # Collect genesis tx
  BINARY genesis collect-gentxs --home=$HOME_DIR

  # Run this to ensure all worked and that the genesis file is setup correctly
  BINARY genesis validate-genesis
}

# check if CLEAN is not set to false
if [ "$CLEAN" != "false" ]; then
  echo "Starting from a clean state"
  from_scratch
fi

echo "Starting node..."

# Opens the RPC endpoint to outside connections
sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/c\laddr = "tcp:\/\/0.0.0.0:'$RPC'"/g' $HOME_DIR/config/config.toml
sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $HOME_DIR/config/config.toml

# REST endpoint
sed -i 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:'$REST'"/g' $HOME_DIR/config/app.toml
sed -i 's/enable = false/enable = true/g' $HOME_DIR/config/app.toml

# replace pprof_laddr = "localhost:6060" binding
sed -i 's/pprof_laddr = "localhost:6060"/pprof_laddr = "localhost:'$PROFF_LADDER'"/g' $HOME_DIR/config/config.toml

# change p2p addr laddr = "tcp://0.0.0.0:26656"
sed -i 's/laddr = "tcp:\/\/0.0.0.0:26656"/laddr = "tcp:\/\/0.0.0.0:'$P2P'"/g' $HOME_DIR/config/config.toml

# GRPC
sed -i 's/address = "localhost:9090"/address = "0.0.0.0:'$GRPC'"/g' $HOME_DIR/config/app.toml
sed -i 's/address = "localhost:9091"/address = "0.0.0.0:'$GRPC_WEB'"/g' $HOME_DIR/config/app.toml

# Rosetta Api
sed -i 's/address = ":8080"/address = "0.0.0.0:'$ROSETTA'"/g' $HOME_DIR/config/app.toml

# faster blocks
sed -i 's/timeout_commit = "5s"/timeout_commit = "'$TIMEOUT_COMMIT'"/g' $HOME_DIR/config/config.toml

# Start the node
BINARY start --pruning=nothing  --minimum-gas-prices=0umfx --rpc.laddr="tcp://0.0.0.0:$RPC"