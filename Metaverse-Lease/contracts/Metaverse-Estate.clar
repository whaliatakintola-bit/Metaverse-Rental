;; Virtual Real Estate Rental Smart Contract
;; This contract manages virtual property rentals with comprehensive functionality

;; =============================================================================
;; CONSTANTS & ERROR CODES
;; =============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPERTY-NOT-FOUND (err u101))
(define-constant ERR-PROPERTY-NOT-AVAILABLE (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-RENTAL-NOT-FOUND (err u104))
(define-constant ERR-RENTAL-EXPIRED (err u105))
(define-constant ERR-RENTAL-ACTIVE (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-PROPERTY-ALREADY-EXISTS (err u108))
(define-constant ERR-INVALID-COORDINATES (err u109))
(define-constant ERR-MAINTENANCE-MODE (err u110))
(define-constant ERR-INVALID-PRICE (err u111))
(define-constant ERR-EARLY-TERMINATION-NOT-ALLOWED (err u112))
(define-constant ERR-INVALID-RATING (err u113))
(define-constant ERR-INVALID-INPUT (err u114))
(define-constant ERR-EMPTY-STRING (err u115))
(define-constant ERR-INVALID-AMOUNT (err u116))

(define-constant MIN-RENTAL-DURATION u1) ;; 1 block minimum
(define-constant MAX-RENTAL-DURATION u144000) ;; ~100 days in blocks
(define-constant PLATFORM-FEE-BASIS-POINTS u250) ;; 2.5%
(define-constant BASIS-POINTS u10000)

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

;; Property structure
(define-map properties
    { property-id: uint }
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
)

;; Rental agreement structure
(define-map rentals
    { rental-id: uint }
    {
        property-id: uint,
        tenant: principal,
        start-block: uint,
        end-block: uint,
        total-cost: uint,
        security-deposit: uint,
        status: (string-ascii 10), ;; "active", "expired", "terminated"
        created-at: uint,
        early-termination-allowed: bool
    }
)

;; User reputation system
(define-map user-reputation
    { user: principal }
    {
        total-rentals: uint,
        successful-rentals: uint,
        total-spent: uint,
        reputation-score: uint, ;; 0-1000 scale
        last-activity: uint
    }
)

;; Property reviews
(define-map property-reviews
    { property-id: uint, reviewer: principal }
    {
        rating: uint, ;; 1-5 stars
        review-text: (string-utf8 500),
        rental-id: uint,
        created-at: uint
    }
)

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var next-property-id uint u1)
(define-data-var next-rental-id uint u1)
(define-data-var platform-fee-recipient principal CONTRACT-OWNER)
(define-data-var maintenance-mode bool false)
(define-data-var total-properties uint u0)
(define-data-var total-active-rentals uint u0)
(define-data-var platform-revenue uint u0)

;; =============================================================================
;; PRIVATE FUNCTIONS
;; =============================================================================

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount PLATFORM-FEE-BASIS-POINTS) BASIS-POINTS)
)

(define-private (update-user-reputation (user principal) (rental-cost uint) (successful bool))
    (let (
        (current-rep (default-to 
                        { total-rentals: u0, successful-rentals: u0, total-spent: u0, 
                          reputation-score: u500, last-activity: u0 }
                        (map-get? user-reputation { user: user })))
        (new-score (if successful
                      (+ (get reputation-score current-rep) u10)
                      (if (>= (get reputation-score current-rep) u20)
                          (- (get reputation-score current-rep) u20)
                          u0)))
        (capped-score (if (> new-score u1000) u1000 new-score))
    )
        (map-set user-reputation 
            { user: user }
            {
                total-rentals: (+ (get total-rentals current-rep) u1),
                successful-rentals: (if successful 
                                    (+ (get successful-rentals current-rep) u1)
                                    (get successful-rentals current-rep)),
                total-spent: (+ (get total-spent current-rep) rental-cost),
                reputation-score: capped-score,
                last-activity: stacks-block-height
            }
        )
    )
)

(define-private (is-valid-coordinate (coord int))
    (and (>= coord -1000000) (<= coord 1000000))
)

(define-private (calculate-security-deposit (total-cost uint))
    (/ total-cost u10) ;; 10% of total cost
)

(define-private (is-valid-property-id (property-id uint))
    (and (> property-id u0) (< property-id (var-get next-property-id)))
)

(define-private (is-valid-rental-id (rental-id uint))
    (and (> rental-id u0) (< rental-id (var-get next-rental-id)))
)

(define-private (is-non-empty-string-ascii (str (string-ascii 50)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-utf8 (str (string-utf8 200)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-utf8-500 (str (string-utf8 500)))
    (> (len str) u0)
)

(define-private (is-valid-property-type (property-type (string-ascii 20)))
    (and (> (len property-type) u0) (<= (len property-type) u20))
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-property (property-id uint))
    (map-get? properties { property-id: property-id })
)

(define-read-only (get-rental (rental-id uint))
    (map-get? rentals { rental-id: rental-id })
)

(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation { user: user })
)

(define-read-only (get-property-review (property-id uint) (reviewer principal))
    (map-get? property-reviews { property-id: property-id, reviewer: reviewer })
)

(define-read-only (is-rental-active (rental-id uint))
    (match (map-get? rentals { rental-id: rental-id })
        rental-info (and 
                        (is-eq (get status rental-info) "active")
                        (> (get end-block rental-info) stacks-block-height))
        false
    )
)

(define-read-only (get-rental-cost (property-id uint) (duration uint))
    (match (map-get? properties { property-id: property-id })
        property-info (ok (* (get price-per-block property-info) duration))
        ERR-PROPERTY-NOT-FOUND
    )
)

(define-read-only (get-platform-stats)
    {
        total-properties: (var-get total-properties),
        total-active-rentals: (var-get total-active-rentals),
        platform-revenue: (var-get platform-revenue),
        maintenance-mode: (var-get maintenance-mode)
    }
)

(define-read-only (get-properties-by-owner (owner principal))
    ;; Note: In a real implementation, you'd want to maintain a separate map
    ;; This is a simplified version for demonstration
    (ok "Use off-chain indexing for efficient owner property lookup")
)

;; =============================================================================
;; PROPERTY MANAGEMENT FUNCTIONS
;; =============================================================================

(define-public (create-property 
    (name (string-ascii 50))
    (description (string-utf8 200))
    (x-coordinate int)
    (y-coordinate int)
    (z-coordinate int)
    (price-per-block uint)
    (property-type (string-ascii 20)))
    
    (let ((property-id (var-get next-property-id)))
        ;; Input validation
        (asserts! (is-non-empty-string-ascii name) ERR-EMPTY-STRING)
        (asserts! (is-non-empty-string-utf8 description) ERR-EMPTY-STRING)
        (asserts! (is-valid-property-type property-type) ERR-INVALID-INPUT)
        (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
        (asserts! (> price-per-block u0) ERR-INVALID-PRICE)
        (asserts! (is-valid-coordinate x-coordinate) ERR-INVALID-COORDINATES)
        (asserts! (is-valid-coordinate y-coordinate) ERR-INVALID-COORDINATES)
        (asserts! (is-valid-coordinate z-coordinate) ERR-INVALID-COORDINATES)
        
        (map-set properties
            { property-id: property-id }
            {
                owner: tx-sender,
                name: name,
                description: description,
                x-coordinate: x-coordinate,
                y-coordinate: y-coordinate,
                z-coordinate: z-coordinate,
                price-per-block: price-per-block,
                is-available: true,
                property-type: property-type,
                created-at: stacks-block-height,
                total-rentals: u0,
                total-revenue: u0
            }
        )
        
        (var-set next-property-id (+ property-id u1))
        (var-set total-properties (+ (var-get total-properties) u1))
        
        (ok property-id)
    )
)

(define-public (update-property-price (property-id uint) (new-price uint))
    (let ((property-info (unwrap! (map-get? properties { property-id: property-id }) 
                                  ERR-PROPERTY-NOT-FOUND)))
        ;; Input validation
        (asserts! (is-valid-property-id property-id) ERR-INVALID-INPUT)
        (asserts! (> new-price u0) ERR-INVALID-PRICE)
        (asserts! (is-eq (get owner property-info) tx-sender) ERR-NOT-AUTHORIZED)
        
        (map-set properties
            { property-id: property-id }
            (merge property-info { price-per-block: new-price })
        )
        
        (ok true)
    )
)

(define-public (toggle-property-availability (property-id uint))
    (let ((property-info (unwrap! (map-get? properties { property-id: property-id }) 
                                  ERR-PROPERTY-NOT-FOUND)))
        ;; Input validation
        (asserts! (is-valid-property-id property-id) ERR-INVALID-INPUT)
        (asserts! (is-eq (get owner property-info) tx-sender) ERR-NOT-AUTHORIZED)
        
        (map-set properties
            { property-id: property-id }
            (merge property-info { is-available: (not (get is-available property-info)) })
        )
        
        (ok (not (get is-available property-info)))
    )
)

;; =============================================================================
;; RENTAL FUNCTIONS
;; =============================================================================

(define-public (create-rental (property-id uint) (duration uint) (early-termination-allowed bool))
    (let (
        (property-info (unwrap! (map-get? properties { property-id: property-id }) 
                                ERR-PROPERTY-NOT-FOUND))
        (rental-id (var-get next-rental-id))
        (total-cost (* (get price-per-block property-info) duration))
        (security-deposit (calculate-security-deposit total-cost))
        (platform-fee (calculate-platform-fee total-cost))
        (total-payment (+ total-cost security-deposit platform-fee))
    )
        ;; Input validation
        (asserts! (is-valid-property-id property-id) ERR-INVALID-INPUT)
        (asserts! (and (>= duration MIN-RENTAL-DURATION) 
                       (<= duration MAX-RENTAL-DURATION)) ERR-INVALID-DURATION)
        (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
        (asserts! (get is-available property-info) ERR-PROPERTY-NOT-AVAILABLE)
        (asserts! (not (is-eq tx-sender (get owner property-info))) ERR-NOT-AUTHORIZED)
        
        ;; Transfer payment
        (try! (stx-transfer? total-payment tx-sender (as-contract tx-sender)))
        
        ;; Pay property owner
        (try! (as-contract (stx-transfer? total-cost tx-sender (get owner property-info))))
        
        ;; Pay platform fee
        (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get platform-fee-recipient))))
        
        ;; Create rental record
        (map-set rentals
            { rental-id: rental-id }
            {
                property-id: property-id,
                tenant: tx-sender,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height duration),
                total-cost: total-cost,
                security-deposit: security-deposit,
                status: "active",
                created-at: stacks-block-height,
                early-termination-allowed: early-termination-allowed
            }
        )
        
        ;; Update property stats
        (map-set properties
            { property-id: property-id }
            (merge property-info 
                {
                    total-rentals: (+ (get total-rentals property-info) u1),
                    total-revenue: (+ (get total-revenue property-info) total-cost),
                    is-available: false
                }
            )
        )
        
        ;; Update counters
        (var-set next-rental-id (+ rental-id u1))
        (var-set total-active-rentals (+ (var-get total-active-rentals) u1))
        (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
        
        ;; Update user reputation
        (update-user-reputation tx-sender total-cost true)
        
        (ok rental-id)
    )
)

(define-public (end-rental (rental-id uint))
    (let ((rental-info (unwrap! (map-get? rentals { rental-id: rental-id }) 
                                ERR-RENTAL-NOT-FOUND)))
        ;; Input validation
        (asserts! (is-valid-rental-id rental-id) ERR-INVALID-INPUT)
        (asserts! (is-eq (get status rental-info) "active") ERR-RENTAL-EXPIRED)
        (asserts! (<= (get end-block rental-info) stacks-block-height) ERR-RENTAL-ACTIVE)
        
        ;; Update rental status
        (map-set rentals
            { rental-id: rental-id }
            (merge rental-info { status: "expired" })
        )
        
        ;; Return security deposit to tenant
        (try! (as-contract (stx-transfer? (get security-deposit rental-info) 
                                         tx-sender (get tenant rental-info))))
        
        ;; Make property available again
        (let ((property-info (unwrap! (map-get? properties { property-id: (get property-id rental-info) }) 
                                      ERR-PROPERTY-NOT-FOUND)))
            (map-set properties
                { property-id: (get property-id rental-info) }
                (merge property-info { is-available: true })
            )
        )
        
        (var-set total-active-rentals (- (var-get total-active-rentals) u1))
        
        (ok true)
    )
)

(define-public (terminate-rental-early (rental-id uint))
    (let ((rental-info (unwrap! (map-get? rentals { rental-id: rental-id }) 
                                ERR-RENTAL-NOT-FOUND)))
        ;; Input validation
        (asserts! (is-valid-rental-id rental-id) ERR-INVALID-INPUT)
        (asserts! (is-eq (get status rental-info) "active") ERR-RENTAL-EXPIRED)
        (asserts! (> (get end-block rental-info) stacks-block-height) ERR-RENTAL-EXPIRED)
        (asserts! (get early-termination-allowed rental-info) ERR-EARLY-TERMINATION-NOT-ALLOWED)
        (asserts! (is-eq tx-sender (get tenant rental-info)) ERR-NOT-AUTHORIZED)
        
        ;; Update rental status
        (map-set rentals
            { rental-id: rental-id }
            (merge rental-info { status: "terminated" })
        )
        
        ;; Return partial security deposit (50% penalty for early termination)
        (let ((partial-deposit (/ (get security-deposit rental-info) u2)))
            (try! (as-contract (stx-transfer? partial-deposit tx-sender (get tenant rental-info))))
        )
        
        ;; Make property available again
        (let ((property-info (unwrap! (map-get? properties { property-id: (get property-id rental-info) }) 
                                      ERR-PROPERTY-NOT-FOUND)))
            (map-set properties
                { property-id: (get property-id rental-info) }
                (merge property-info { is-available: true })
            )
        )
        
        (var-set total-active-rentals (- (var-get total-active-rentals) u1))
        
        (ok true)
    )
)

;; =============================================================================
;; REVIEW SYSTEM
;; =============================================================================

(define-public (add-property-review 
    (property-id uint) 
    (rental-id uint) 
    (rating uint) 
    (review-text (string-utf8 500)))
    
    (let ((rental-info (unwrap! (map-get? rentals { rental-id: rental-id }) 
                                ERR-RENTAL-NOT-FOUND)))
        ;; Input validation
        (asserts! (is-valid-property-id property-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-rental-id rental-id) ERR-INVALID-INPUT)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
        (asserts! (is-non-empty-string-utf8-500 review-text) ERR-EMPTY-STRING)
        (asserts! (is-eq (get tenant rental-info) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get property-id rental-info) property-id) ERR-PROPERTY-NOT-FOUND)
        (asserts! (is-eq (get status rental-info) "expired") ERR-RENTAL-ACTIVE)
        
        (map-set property-reviews
            { property-id: property-id, reviewer: tx-sender }
            {
                rating: rating,
                review-text: review-text,
                rental-id: rental-id,
                created-at: stacks-block-height
            }
        )
        
        (ok true)
    )
)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-maintenance-mode (enabled bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set maintenance-mode enabled)
        (ok enabled)
    )
)

(define-public (set-platform-fee-recipient (new-recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        ;; Validate that the new recipient is not the zero address
        ;; In Stacks, we can check if it's a valid principal by ensuring it's not equal to the contract itself
        (asserts! (not (is-eq new-recipient (as-contract tx-sender))) ERR-INVALID-INPUT)
        (var-set platform-fee-recipient new-recipient)
        (ok true)
    )
)

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER))
    )
)

;; =============================================================================
;; CONTRACT INITIALIZATION
;; =============================================================================

;; The contract is ready to use upon deployment
;; Initial state: no properties, no rentals, maintenance mode off