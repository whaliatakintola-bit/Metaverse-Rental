# Virtual Real Estate Rental Smart Contract

## Overview

This Clarity smart contract manages virtual property rentals with comprehensive functionality including property management, rental agreements, user reputation system, and property reviews. Built for the Stacks blockchain, it enables decentralized virtual real estate transactions with security deposits, platform fees, and early termination options.

## Features

### Core Functionality
- **Property Management**: Create, update, and manage virtual properties with 3D coordinates
- **Rental System**: Secure rental agreements with customizable duration and terms
- **Security Deposits**: Automated security deposit handling with partial refunds for early termination
- **Platform Fees**: Built-in fee collection system (2.5% of rental cost)
- **User Reputation**: Track user activity and reputation scores (0-1000 scale)
- **Review System**: Property rating and review system for completed rentals

### Security Features
- **Access Control**: Owner-only functions for property management
- **Input Validation**: Comprehensive validation for all user inputs
- **Maintenance Mode**: Emergency pause functionality for contract operations
- **Early Termination**: Optional early termination with penalty system

## Contract Structure

### Constants
- `MIN-RENTAL-DURATION`: 1 block minimum rental period
- `MAX-RENTAL-DURATION`: 144,000 blocks (~100 days maximum)
- `PLATFORM-FEE-BASIS-POINTS`: 250 (2.5% platform fee)
- Various error codes for different failure scenarios

### Data Structures

#### Properties
```clarity
{
    owner: principal,
    name: (string-ascii 50),
    description: (string-utf8 200),
    x-coordinate: int,
    y-coordinate: int,
    z-coordinate: int,
    price-per-block: uint,
    is-available: bool,
    property-type: (string-ascii 20),
    created-at: uint,
    total-rentals: uint,
    total-revenue: uint
}
```

#### Rentals
```clarity
{
    property-id: uint,
    tenant: principal,
    start-block: uint,
    end-block: uint,
    total-cost: uint,
    security-deposit: uint,
    status: (string-ascii 10),
    created-at: uint,
    early-termination-allowed: bool
}
```

#### User Reputation
```clarity
{
    total-rentals: uint,
    successful-rentals: uint,
    total-spent: uint,
    reputation-score: uint,
    last-activity: uint
}
```

## Function Reference

### Property Management

#### `create-property`
Creates a new virtual property listing.

**Parameters:**
- `name` (string-ascii 50): Property name
- `description` (string-utf8 200): Property description
- `x-coordinate` (int): X coordinate in virtual space
- `y-coordinate` (int): Y coordinate in virtual space
- `z-coordinate` (int): Z coordinate in virtual space
- `price-per-block` (uint): Rental price per block
- `property-type` (string-ascii 20): Type of property

**Returns:** Property ID on success

#### `update-property-price`
Updates the rental price of an existing property (owner only).

**Parameters:**
- `property-id` (uint): ID of the property
- `new-price` (uint): New price per block

#### `toggle-property-availability`
Toggles the availability status of a property (owner only).

**Parameters:**
- `property-id` (uint): ID of the property

### Rental Management

#### `create-rental`
Creates a new rental agreement.

**Parameters:**
- `property-id` (uint): ID of the property to rent
- `duration` (uint): Rental duration in blocks
- `early-termination-allowed` (bool): Whether early termination is permitted

**Returns:** Rental ID on success

**Payment Structure:**
- Base rental cost: `property-price * duration`
- Security deposit: 10% of total cost
- Platform fee: 2.5% of rental cost
- Total payment: `rental-cost + security-deposit + platform-fee`

#### `end-rental`
Ends an expired rental and returns security deposit.

**Parameters:**
- `rental-id` (uint): ID of the rental to end

#### `terminate-rental-early`
Allows tenant to terminate rental before expiration (if allowed).

**Parameters:**
- `rental-id` (uint): ID of the rental to terminate

**Note:** 50% penalty applied to security deposit for early termination.

### Review System

#### `add-property-review`
Adds a review for a completed rental.

**Parameters:**
- `property-id` (uint): ID of the reviewed property
- `rental-id` (uint): ID of the completed rental
- `rating` (uint): Rating from 1-5 stars
- `review-text` (string-utf8 500): Review text

### Read-Only Functions

#### `get-property`
Retrieves property information by ID.

#### `get-rental`
Retrieves rental information by ID.

#### `get-user-reputation`
Retrieves user reputation data.

#### `is-rental-active`
Checks if a rental is currently active.

#### `get-rental-cost`
Calculates rental cost for a property and duration.

#### `get-platform-stats`
Returns overall platform statistics.

### Admin Functions

#### `set-maintenance-mode`
Enables/disables maintenance mode (contract owner only).

#### `set-platform-fee-recipient`
Updates the platform fee recipient address (contract owner only).

#### `emergency-withdraw`
Emergency withdrawal function for contract owner.

## Error Codes

- `u100`: Not authorized
- `u101`: Property not found
- `u102`: Property not available
- `u103`: Insufficient payment
- `u104`: Rental not found
- `u105`: Rental expired
- `u106`: Rental active
- `u107`: Invalid duration
- `u108`: Property already exists
- `u109`: Invalid coordinates
- `u110`: Maintenance mode
- `u111`: Invalid price
- `u112`: Early termination not allowed
- `u113`: Invalid rating
- `u114`: Invalid input
- `u115`: Empty string
- `u116`: Invalid amount

## Usage Examples

### Creating a Property
```clarity
(contract-call? .virtual-real-estate create-property
    "Luxury Villa"
    u"Beautiful virtual villa with ocean view"
    100
    200
    50
    u1000
    "villa"
)
```

### Renting a Property
```clarity
(contract-call? .virtual-real-estate create-rental
    u1    ;; property-id
    u144  ;; duration (1 day in blocks)
    true  ;; early-termination-allowed
)
```

### Adding a Review
```clarity
(contract-call? .virtual-real-estate add-property-review
    u1    ;; property-id
    u1    ;; rental-id
    u5    ;; rating (5 stars)
    u"Amazing property! Highly recommended."
)
```