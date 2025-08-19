# Transidao - Public Transit Funding DAO

A decentralized autonomous organization for managing public transit funding with citizen-managed fare systems on the Stacks blockchain.

## Overview

Transidao enables communities to democratically manage public transportation funding through governance tokens, proposal voting, and transparent fare collection. Citizens can join the DAO, propose improvements, vote on fare adjustments, and ensure sustainable transit operations.

## Features

- **DAO Membership**: Stake-based membership system with reputation tracking
- **Democratic Governance**: Proposal creation and voting system for funding and fare decisions
- **Fare Management**: Dynamic fare zones and route-based pricing
- **Revenue Tracking**: Daily revenue collection and transparent fund distribution
- **Treasury Management**: Collective fund management with member oversight

## Smart Contract Functions

### Membership Functions

#### `join-dao`
Join the DAO by staking STX tokens.
```clarity
(contract-call? .Transidao join-dao u1000)
```

#### `leave-dao`
Leave the DAO and retrieve staked tokens.
```clarity
(contract-call? .Transidao leave-dao)
```

### Governance Functions

#### `create-proposal`
Create a new proposal for voting (requires minimum stake threshold).
```clarity
(contract-call? .Transidao create-proposal 
    "New Bus Route" 
    "Proposal to add bus route between downtown and airport" 
    u50000 
    "funding")
```

#### `vote-on-proposal`
Vote on an active proposal with your stake-weighted power.
```clarity
(contract-call? .Transidao vote-on-proposal u1 true)
```

#### `execute-proposal`
Execute a passed proposal after voting period ends.
```clarity
(contract-call? .Transidao execute-proposal u1)
```

### Fare System Functions

#### `pay-fare`
Pay transit fare between zones.
```clarity
(contract-call? .Transidao pay-fare u1 u3)
```

#### `create-fare-zone`
Create a new fare zone (requires governance privilege).
```clarity
(contract-call? .Transidao create-fare-zone "Downtown" u150 u150)
```

#### `set-route-fare`
Set specific fare for route between zones.
```clarity
(contract-call? .Transidao set-route-fare u1 u2 u200)
```

### Read-Only Functions

#### `get-member-info`
Get member information including stake and reputation.
```clarity
(contract-call? .Transidao get-member-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### `get-dao-treasury`
Get current DAO treasury balance.
```clarity
(contract-call? .Transidao get-dao-treasury)
```

#### `get-current-fare`
Get the base fare amount.
```clarity
(contract-call? .Transidao get-current-fare)
```

## Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Stacks wallet with STX tokens

### Development Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd Transidao
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

4. Deploy to testnet:
```bash
clarinet deployments apply --devnet
```

## Usage Examples

### Joining the DAO
1. Stake minimum required STX (default: 1000 µSTX)
2. Gain voting rights proportional to stake
3. Participate in governance and fare decisions

### Creating Proposals
1. Must be active DAO member with sufficient stake
2. Specify proposal type: "funding" or "fare-adjustment"
3. Provide clear title and description
4. Set appropriate funding amount

### Fare Payment Flow
1. User pays fare for specific route
2. Payment goes to DAO treasury
3. Revenue tracked for transparency
4. Funds available for approved proposals

## Governance Parameters

- **Membership Fee**: 1000 µSTX minimum stake
- **Proposal Threshold**: 500 µSTX minimum for proposals  
- **Voting Period**: 144 blocks (~24 hours)
- **Base Fare**: 100 µSTX (adjustable via governance)

## Contract Constants

- `ERR_UNAUTHORIZED` (401): Insufficient permissions
- `ERR_NOT_FOUND` (404): Resource not found
- `ERR_INVALID_AMOUNT` (400): Invalid amount specified
- `ERR_ALREADY_MEMBER` (409): Already a DAO member
- `ERR_NOT_MEMBER` (403): Not a DAO member

## Security Considerations

- All transfers use built-in STX transfer functions
- Member authorization required for critical operations
- Proposal execution requires majority vote approval
- Treasury operations require elevated stake requirements

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create feature branch
3. Write tests for new features
4. Submit pull request with clear description

## Support

For issues and questions, please open a GitHub issue or contact the development team.
