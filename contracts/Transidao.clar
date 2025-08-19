;; title: Transidao
;; version: 1.0.0
;; summary: Public Transit Funding DAO with citizen-managed fare systems
;; description: A decentralized autonomous organization for managing public transit funding, fare collection, and governance

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_ALREADY_MEMBER (err u409))
(define-constant ERR_NOT_MEMBER (err u403))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u410))
(define-constant ERR_ALREADY_VOTED (err u411))
(define-constant ERR_INSUFFICIENT_FUNDS (err u412))
(define-constant ERR_INVALID_PROPOSAL (err u413))
(define-constant ERR_PROPOSAL_EXPIRED (err u414))

(define-data-var dao-treasury uint u0)
(define-data-var member-count uint u0)
(define-data-var proposal-count uint u0)
(define-data-var base-fare uint u100)
(define-data-var membership-fee uint u1000)
(define-data-var proposal-threshold uint u500)
(define-data-var voting-period uint u144)

(define-map dao-members principal {
    stake: uint,
    joined-at: uint,
    reputation: uint,
    active: bool
})

(define-map proposals uint {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    expires-at: uint,
    executed: bool,
    proposal-type: (string-ascii 20)
})

(define-map votes {proposal-id: uint, voter: principal} {
    vote: bool,
    power: uint
})

(define-map fare-zones uint {
    zone-name: (string-ascii 50),
    base-rate: uint,
    peak-multiplier: uint,
    active: bool
})

(define-map route-fares {from-zone: uint, to-zone: uint} uint)

(define-map daily-revenue uint uint)

(define-data-var zone-count uint u0)

(define-public (join-dao (stake-amount uint))
    (let ((member-info (map-get? dao-members tx-sender)))
        (asserts! (is-none member-info) ERR_ALREADY_MEMBER)
        (asserts! (>= stake-amount (var-get membership-fee)) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        (map-set dao-members tx-sender {
            stake: stake-amount,
            joined-at: stacks-block-height,
            reputation: u100,
            active: true
        })
        (var-set dao-treasury (+ (var-get dao-treasury) stake-amount))
        (var-set member-count (+ (var-get member-count) u1))
        (ok true)
    )
)

(define-public (leave-dao)
    (let ((member-info (unwrap! (map-get? dao-members tx-sender) ERR_NOT_MEMBER)))
        (asserts! (get active member-info) ERR_NOT_MEMBER)
        (let ((stake (get stake member-info)))
            (asserts! (<= stake (var-get dao-treasury)) ERR_INSUFFICIENT_FUNDS)
            (try! (as-contract (stx-transfer? stake tx-sender tx-sender)))
            (map-delete dao-members tx-sender)
            (var-set dao-treasury (- (var-get dao-treasury) stake))
            (var-set member-count (- (var-get member-count) u1))
            (ok stake)
        )
    )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (proposal-type (string-ascii 20)))
    (let ((member-info (unwrap! (map-get? dao-members tx-sender) ERR_NOT_MEMBER)))
        (asserts! (get active member-info) ERR_NOT_MEMBER)
        (asserts! (>= (get stake member-info) (var-get proposal-threshold)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (let ((proposal-id (+ (var-get proposal-count) u1)))
            (map-set proposals proposal-id {
                proposer: tx-sender,
                title: title,
                description: description,
                amount: amount,
                votes-for: u0,
                votes-against: u0,
                created-at: stacks-block-height,
                expires-at: (+ stacks-block-height (var-get voting-period)),
                executed: false,
                proposal-type: proposal-type
            })
            (var-set proposal-count proposal-id)
            (ok proposal-id)
        )
    )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let ((member-info (unwrap! (map-get? dao-members tx-sender) ERR_NOT_MEMBER))
          (proposal-info (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND)))
        (asserts! (get active member-info) ERR_NOT_MEMBER)
        (asserts! (< stacks-block-height (get expires-at proposal-info)) ERR_PROPOSAL_EXPIRED)
        (asserts! (not (get executed proposal-info)) ERR_PROPOSAL_NOT_ACTIVE)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
        (let ((vote-power (get stake member-info)))
            (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
                vote: vote-for,
                power: vote-power
            })
            (if vote-for
                (map-set proposals proposal-id (merge proposal-info {
                    votes-for: (+ (get votes-for proposal-info) vote-power)
                }))
                (map-set proposals proposal-id (merge proposal-info {
                    votes-against: (+ (get votes-against proposal-info) vote-power)
                }))
            )
            (ok true)
        )
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal-info (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND)))
        (asserts! (>= stacks-block-height (get expires-at proposal-info)) ERR_PROPOSAL_NOT_ACTIVE)
        (asserts! (not (get executed proposal-info)) ERR_PROPOSAL_NOT_ACTIVE)
        (asserts! (> (get votes-for proposal-info) (get votes-against proposal-info)) ERR_PROPOSAL_NOT_ACTIVE)
        (let ((proposal-amount (get amount proposal-info)))
            (if (is-eq (get proposal-type proposal-info) "funding")
                (begin
                    (asserts! (<= proposal-amount (var-get dao-treasury)) ERR_INSUFFICIENT_FUNDS)
                    (try! (as-contract (stx-transfer? proposal-amount tx-sender (get proposer proposal-info))))
                    (var-set dao-treasury (- (var-get dao-treasury) proposal-amount))
                    (map-set proposals proposal-id (merge proposal-info {executed: true}))
                    (ok true)
                )
                (begin
                    (if (is-eq (get proposal-type proposal-info) "fare-adjustment")
                        (begin
                            (var-set base-fare proposal-amount)
                            (map-set proposals proposal-id (merge proposal-info {executed: true}))
                            (ok true)
                        )
                        ERR_INVALID_PROPOSAL
                    )
                )
            )
        )
    )
)

(define-public (pay-fare (from-zone uint) (to-zone uint))
    (let ((fare-amount (unwrap! (map-get? route-fares {from-zone: from-zone, to-zone: to-zone}) (ok (var-get base-fare)))))
        (try! (stx-transfer? fare-amount tx-sender (as-contract tx-sender)))
        (var-set dao-treasury (+ (var-get dao-treasury) fare-amount))
        (let ((today (/ stacks-block-height u144)))
            (map-set daily-revenue today 
                (+ (default-to u0 (map-get? daily-revenue today)) fare-amount))
        )
        (ok fare-amount)
    )
)

(define-public (create-fare-zone (zone-name (string-ascii 50)) (base-rate uint) (peak-multiplier uint))
    (let ((member-info (unwrap! (map-get? dao-members tx-sender) ERR_NOT_MEMBER)))
        (asserts! (get active member-info) ERR_NOT_MEMBER)
        (asserts! (>= (get stake member-info) (var-get proposal-threshold)) ERR_UNAUTHORIZED)
        (let ((zone-id (+ (var-get zone-count) u1)))
            (map-set fare-zones zone-id {
                zone-name: zone-name,
                base-rate: base-rate,
                peak-multiplier: peak-multiplier,
                active: true
            })
            (var-set zone-count zone-id)
            (ok zone-id)
        )
    )
)

(define-public (set-route-fare (from-zone uint) (to-zone uint) (fare uint))
    (let ((member-info (unwrap! (map-get? dao-members tx-sender) ERR_NOT_MEMBER)))
        (asserts! (get active member-info) ERR_NOT_MEMBER)
        (asserts! (>= (get stake member-info) (var-get proposal-threshold)) ERR_UNAUTHORIZED)
        (map-set route-fares {from-zone: from-zone, to-zone: to-zone} fare)
        (ok true)
    )
)

(define-public (distribute-revenue (recipient principal) (amount uint))
    (let ((member-info (unwrap! (map-get? dao-members tx-sender) ERR_NOT_MEMBER)))
        (asserts! (get active member-info) ERR_NOT_MEMBER)
        (asserts! (>= (get stake member-info) (* (var-get proposal-threshold) u2)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get dao-treasury)) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (var-set dao-treasury (- (var-get dao-treasury) amount))
        (ok true)
    )
)

(define-read-only (get-member-info (member principal))
    (map-get? dao-members member)
)

(define-read-only (get-proposal-info (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote-info (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-dao-treasury)
    (var-get dao-treasury)
)

(define-read-only (get-member-count)
    (var-get member-count)
)

(define-read-only (get-current-fare)
    (var-get base-fare)
)

(define-read-only (get-route-fare (from-zone uint) (to-zone uint))
    (map-get? route-fares {from-zone: from-zone, to-zone: to-zone})
)

(define-read-only (get-fare-zone (zone-id uint))
    (map-get? fare-zones zone-id)
)

(define-read-only (get-daily-revenue (day uint))
    (map-get? daily-revenue day)
)

(define-read-only (get-proposal-count)
    (var-get proposal-count)
)

(define-read-only (is-member (address principal))
    (match (map-get? dao-members address)
        member-info (get active member-info)
        false
    )
)
