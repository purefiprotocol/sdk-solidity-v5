# PureFi Solidity SDK V5

## 📦 Overview

The `PureFi Solidity SDK V5` is a SDK designed for efficient, gas-optimized integration with the PureFi Protocol. It provides a set of internal pure functions that use inline assembly to retrieve various components of a structured byte payload.

## ✨ Features

- Ultra-gas-efficient data extraction using inline assembly
- Supports extracting multiple data types from a single bytes payload
- Flexible package type detection with bitwise flag checking
- Built-in safety checks for specific package configurations

## 🏗️ Structure Composition

Each package type struct contains the following common fields:

- `packageType`: An 8-bit unsigned integer identifying the package type
- `session`: A 256-bit session identifier
- `rule`: A 256-bit rule identifier
- `from`: The sender's address
- `to`: The recipient's address

## 📋 Package Types Breakdown

### Basic Package Types

| Package Type | Unique Fields              | Additional Information                         |
|--------------|----------------------------|------------------------------------------------|
| Type 1       | None                       | Minimal package with basic routing information |
| Type 2       | `token0`, `tokenAmount0`   | Includes token transfer details                |
| Type 32      | `tokenData0`               | Single token-related data                      |
| Type 48      | `tokenData0`, `tokenData1` | Two pieces of token-related data               |

### Payment-Related Package Types

| Package Type | Unique Fields                                      | Additional Information             |
|--------------|----------------------------------------------------|------------------------------------|
| Type 64      | `payee`, `paymentData`                             | Basic payment package              |
| Type 96      | `payee`, `paymentData`, `tokenData0`               | Payment with additional token data |
| Type 112     | `payee`, `paymentData`, `tokenData0`, `tokenData1` | Complex payment package            |

### Intermediary Package Types

| Package Type | Unique Fields                                                      | Additional Information                       |
|--------------|--------------------------------------------------------------------|----------------------------------------------|
| Type 128     | `intermediary`                                                     | Package with intermediary routing            |
| Type 160     | `intermediary`, `tokenData0`                                       | Similar to Type 128                          |
| Type 176     | `intermediary`, `tokenData0`, `tokenData1`                         | Intermediary with multiple token data points |
| Type 192     | `intermediary`, `payee`, `paymentData`                             | Intermediary payment package                 |
| Type 224     | `intermediary`, `payee`, `paymentData`, `tokenData0`               | Complex intermediary payment                 |
| Type 240     | `intermediary`, `payee`, `paymentData`, `tokenData0`, `tokenData1` | Most complex intermediary package            |


## 💻 Usage Example

```solidity
contract PureFiExample {
    using PureFiDataLibrary for bytes;
    IPureFiVerifier public verifier;
    uint256 public requiredRuleId;

    constructor(address _verifier, uint256 _requiredRuleId) {
        verifier = IPureFiVerifier(_verifier);
        requiredRuleId = _requiredRuleId;
    }

    function buy(bytes calldata _purefidata) external payable {
        verifier.validatePayload(_purefidata);
        bytes calldata package = _purefidata.getPackage();
        require(package.getRule() == requiredRuleId, "Invalid ruleId");
        // Purchase logic here
    }
}
```

## 🛡️ Security Considerations

- These functions assume a specific, predefined byte layout
- Always validate input data structure before processing
- Use with carefully constructed byte payloads
- Potential for runtime errors if byte structure is incorrect

## 🚀 Gas Optimization

The library uses inline assembly for maximum gas efficiency, minimizing the computational cost of data extraction.

## 📥 Installation

Add to your Hardhat/Foundry project:

```bash
# Using Foundry
forge install purefiprotocol/sdk-solidity-v5
```

Add to `remappings.txt`
```
@purefi-sdk-solidity-v5/=lib/sdk-solidity-v5/src/
```

or you can use 

```shell
npm i @purefi/sdk-solidity-v5
```

## 🔗 Dependencies

- Solidity ^0.8.20
- Minimal external dependencies

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request


### Deploy

```shell
$ forge script script/PureFiVerifierDeployment.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```
