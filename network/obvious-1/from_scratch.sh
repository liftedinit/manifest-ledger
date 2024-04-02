# Takes a default genesis from manifestd and creates a new genesis file.

CHAIN_ID=obvious-1

make install

export HOME_DIR=$(eval echo "${HOME_DIR:-"~/.manifest"}")

rm -rf $HOME_DIR && echo "Removed $HOME_DIR"

manifestd init moniker --chain-id=$CHAIN_ID --default-denom=umfx

update_genesis () {
    cat $HOME_DIR/config/genesis.json | jq "$1" > $HOME_DIR/config/tmp_genesis.json && mv $HOME_DIR/config/tmp_genesis.json $HOME_DIR/config/genesis.json
}

update_genesis '.consensus["params"]["block"]["max_gas"]="-1"'
update_genesis '.consensus["params"]["abci"]["vote_extensions_enable_height"]="1"'

# auth
update_genesis '.app_state["auth"]["params"]["max_memo_characters"]="512"'

update_genesis '.app_state["bank"]["denom_metadata"]=[
        {
            "base": "umfx",
            "denom_units": [
            {
                "aliases": [],
                "denom": "umfx",
                "exponent": 0
            },
            {
                "aliases": [],
                "denom": "MFX",
                "exponent": 6
            }
            ],
            "description": "Denom metadata for MFX (umfx)",
            "display": "MFX",
            "name": "MFX",
            "symbol": "MFX"
        }
]'

update_genesis '.app_state["crisis"]["constant_fee"]={"denom": "umfx","amount": "100000000"}'

update_genesis '.app_state["distribution"]["params"]["community_tax"]="0.000000000000000000"'

update_genesis '.app_state["gov"]["params"]["min_deposit"]=[{"denom":"umfx","amount":"100000000"}]'
update_genesis '.app_state["gov"]["params"]["max_deposit_period"]="259200s"'
update_genesis '.app_state["gov"]["params"]["voting_period"]="259200s"'
update_genesis '.app_state["gov"]["params"]["expedited_min_deposit"]=[{"denom":"umfx","amount":"250000000"}]'
update_genesis '.app_state["gov"]["params"]["min_deposit_ratio"]="0.100000000000000000"' # 10%
# update_genesis '.app_state["gov"]["params"]["constitution"]=""' # ?

# TODO:
# update_genesis '.app_state["manifest"]["params"]["stake_holders"]=[{"address":"manifest1hj5fveer5cjtn4wd6wstzugjfdxzl0xp8ws9ct","percentage":100000000}]' # TODO:
update_genesis '.app_state["manifest"]["params"]["inflation"]["automatic_enabled"]=false'
update_genesis '.app_state["manifest"]["params"]["inflation"]["yearly_amount"]="365000000"' # in micro format (1MFX = 10**6)
update_genesis '.app_state["manifest"]["params"]["inflation"]["mint_denom"]="umfx"'

# not used
update_genesis '.app_state["mint"]["minter"]["inflation"]="0.000000000000000000"'
update_genesis '.app_state["mint"]["minter"]["annual_provisions"]="0.000000000000000000"'
update_genesis '.app_state["mint"]["params"]["mint_denom"]="notused"'
update_genesis '.app_state["mint"]["params"]["inflation_rate_change"]="0.000000000000000000"'
update_genesis '.app_state["mint"]["params"]["inflation_max"]="0.000000000000000000"'
update_genesis '.app_state["mint"]["params"]["inflation_min"]="0.000000000000000000"'
update_genesis '.app_state["mint"]["params"]["blocks_per_year"]="6311520"' # default 6s blocks

update_genesis '.app_state["slashing"]["params"]["signed_blocks_window"]="10000"'
update_genesis '.app_state["slashing"]["params"]["min_signed_per_window"]="0.050000000000000000"'
update_genesis '.app_state["slashing"]["params"]["downtime_jail_duration"]="60s"'
update_genesis '.app_state["slashing"]["params"]["slash_fraction_double_sign"]="1.000000000000000000"'
update_genesis '.app_state["slashing"]["params"]["slash_fraction_downtime"]="0.000000000000000000"'

update_genesis '.app_state["staking"]["params"]["bond_denom"]="poastake"'

update_genesis '.app_state["tokenfactory"]["params"]["denom_creation_fee"]=[]'
update_genesis '.app_state["tokenfactory"]["params"]["denom_creation_gas_consume"]="250000"'

# TODO: chalabi / the multisig
# gov, reece-testnet, chandrastation, chandra-reece-multisig
update_genesis '.app_state["poa"]["params"]["admins"]=["manifest10d07y265gmmuvt4z0w9aw880jnsr700jmq3jzm","manifest1aucdev30u9505dx9t6q5fkcm70sjg4rh7rn5nf","manifest1wxjfftrc0emj5f7ldcvtpj05lxtz3t2npghwsf","manifest1nzpct7tq52rckgnvr55e2m0kmyr0asdrgayq9p"]'

# add genesis accounts
# TODO:
manifestd genesis add-genesis-account manifest1hj5fveer5cjtn4wd6wstzugjfdxzl0xp8ws9ct 1umfx --append
manifestd genesis add-genesis-account manifest1aucdev30u9505dx9t6q5fkcm70sjg4rh7rn5nf 5000000000000umfx --append # reece-testnet (5m UMFX). Is a validator
manifestd genesis add-genesis-account manifest1wxjfftrc0emj5f7ldcvtpj05lxtz3t2npghwsf 5000000000000umfx --append # chandrastation
manifestd genesis add-genesis-account manifest1nzpct7tq52rckgnvr55e2m0kmyr0asdrgayq9p 5000000000000umfx --append # multisig

cp ~/.manifest/config/genesis.json ./network/$CHAIN_ID/genesis.json