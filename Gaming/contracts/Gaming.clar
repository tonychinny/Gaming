;; Gaming - Play-to-Earn Tournament Platform
;; Create tournaments, compete for prizes, and earn rewards through gaming

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_TOURNAMENT_FULL (err u403))
(define-constant ERR_TOURNAMENT_ENDED (err u405))
(define-constant ERR_INVALID_SCORE (err u400))
(define-constant ERR_ALREADY_REGISTERED (err u406))
(define-constant ERR_INSUFFICIENT_ENTRY_FEE (err u402))
(define-constant ERR_PRIZES_DISTRIBUTED (err u407))

;; Variables
(define-data-var tournament-counter uint u0)
(define-data-var match-counter uint u0)
(define-data-var platform-fee uint u500) ;; 5%

;; Tournament data
(define-map tournaments
    { tournament-id: uint }
    {
        organizer: principal,
        name: (string-utf8 50),
        game-type: (string-utf8 30),
        entry-fee: uint,
        prize-pool: uint,
        max-players: uint,
        current-players: uint,
        start-block: uint,
        end-block: uint,
        is-active: bool,
        prizes-distributed: bool
    }
)

;; Player registrations
(define-map tournament-players
    { tournament-id: uint, player: principal }
    {
        registered-at: uint,
        entry-fee-paid: uint,
        final-score: uint,
        final-rank: uint,
        prize-won: uint,
        prize-claimed: bool
    }
)

;; Game matches/sessions
(define-map game-matches
    { match-id: uint }
    {
        tournament-id: uint,
        player: principal,
        score: uint,
        game-duration: uint,
        completed-at: uint,
        verified: bool
    }
)

;; Leaderboards
(define-map tournament-rankings
    { tournament-id: uint, rank: uint }
    {
        player: principal,
        score: uint,
        prize-amount: uint
    }
)

;; Player stats
(define-map player-stats
    { player: principal }
    {
        tournaments-played: uint,
        tournaments-won: uint,
        total-winnings: uint,
        best-score: uint,
        games-played: uint,
        average-score: uint
    }
)

;; Achievement system
(define-map player-achievements
    { player: principal, achievement-id: uint }
    {
        achievement-name: (string-utf8 50),
        earned-at: uint,
        tournament-id: uint
    }
)

(define-data-var achievement-counter uint u0)

;; Read-only functions
(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments { tournament-id: tournament-id })
)

(define-read-only (get-player-registration (tournament-id uint) (player principal))
    (map-get? tournament-players { tournament-id: tournament-id, player: player })
)

(define-read-only (get-match (match-id uint))
    (map-get? game-matches { match-id: match-id })
)

(define-read-only (get-ranking (tournament-id uint) (rank uint))
    (map-get? tournament-rankings { tournament-id: tournament-id, rank: rank })
)

(define-read-only (get-player-stats (player principal))
    (default-to 
        { tournaments-played: u0, tournaments-won: u0, total-winnings: u0, best-score: u0, games-played: u0, average-score: u0 }
        (map-get? player-stats { player: player })
    )
)

(define-read-only (tournament-active (tournament-id uint))
    (match (get-tournament tournament-id)
        tournament (and
            (get is-active tournament)
            (>= stacks-block-height (get start-block tournament))
            (<= stacks-block-height (get end-block tournament))
        )
        false
    )
)

(define-read-only (registration-open (tournament-id uint))
    (match (get-tournament tournament-id)
        tournament (and
            (get is-active tournament)
            (< stacks-block-height (get start-block tournament))
            (< (get current-players tournament) (get max-players tournament))
        )
        false
    )
)

(define-read-only (get-tournament-count)
    (var-get tournament-counter)
)

;; Public functions
(define-public (create-tournament 
    (name (string-utf8 50))
    (game-type (string-utf8 30))
    (entry-fee uint)
    (max-players uint)
    (duration uint))
    (let (
        (tournament-id (+ (var-get tournament-counter) u1))
        (start-block (+ stacks-block-height u100)) ;; Registration period
        (end-block (+ start-block duration))
    )
        (asserts! (> max-players u1) ERR_INVALID_SCORE)
        (asserts! (> duration u0) ERR_INVALID_SCORE)
        (asserts! (>= entry-fee u0) ERR_INVALID_SCORE)
        
        (map-set tournaments
            { tournament-id: tournament-id }
            {
                organizer: tx-sender,
                name: name,
                game-type: game-type,
                entry-fee: entry-fee,
                prize-pool: u0,
                max-players: max-players,
                current-players: u0,
                start-block: start-block,
                end-block: end-block,
                is-active: true,
                prizes-distributed: false
            }
        )
        
        (var-set tournament-counter tournament-id)
        (ok tournament-id)
    )
)

(define-public (register-for-tournament (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) ERR_NOT_FOUND))
        (existing-registration (get-player-registration tournament-id tx-sender))
        (player-current-stats (get-player-stats tx-sender))
    )
        (asserts! (registration-open tournament-id) ERR_TOURNAMENT_ENDED)
        (asserts! (is-none existing-registration) ERR_ALREADY_REGISTERED)
        (asserts! (< (get current-players tournament) (get max-players tournament)) ERR_TOURNAMENT_FULL)
        
        ;; Register player
        (map-set tournament-players
            { tournament-id: tournament-id, player: tx-sender }
            {
                registered-at: stacks-block-height,
                entry-fee-paid: (get entry-fee tournament),
                final-score: u0,
                final-rank: u0,
                prize-won: u0,
                prize-claimed: false
            }
        )
        
        ;; Update tournament
        (map-set tournaments
            { tournament-id: tournament-id }
            (merge tournament {
                current-players: (+ (get current-players tournament) u1),
                prize-pool: (+ (get prize-pool tournament) (get entry-fee tournament))
            })
        )
        
        ;; Update player stats
        (map-set player-stats
            { player: tx-sender }
            (merge player-current-stats {
                tournaments-played: (+ (get tournaments-played player-current-stats) u1)
            })
        )
        
        (ok true)
    )
)

(define-public (submit-score (tournament-id uint) (score uint) (game-duration uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) ERR_NOT_FOUND))
        (registration (unwrap! (get-player-registration tournament-id tx-sender) ERR_NOT_FOUND))
        (match-id (+ (var-get match-counter) u1))
        (player-current-stats (get-player-stats tx-sender))
    )
        (asserts! (tournament-active tournament-id) ERR_TOURNAMENT_ENDED)
        (asserts! (> score u0) ERR_INVALID_SCORE)
        
        ;; Record match
        (map-set game-matches
            { match-id: match-id }
            {
                tournament-id: tournament-id,
                player: tx-sender,
                score: score,
                game-duration: game-duration,
                completed-at: stacks-block-height,
                verified: false
            }
        )
        
        ;; Update player registration with best score
        (if (> score (get final-score registration))
            (map-set tournament-players
                { tournament-id: tournament-id, player: tx-sender }
                (merge registration { final-score: score })
            )
            true
        )
        
        ;; Update player stats
        (map-set player-stats
            { player: tx-sender }
            (merge player-current-stats {
                games-played: (+ (get games-played player-current-stats) u1),
                best-score: (if (> score (get best-score player-current-stats)) 
                    score 
                    (get best-score player-current-stats)),
                average-score: (/ (+ (* (get average-score player-current-stats) (get games-played player-current-stats)) score) 
                                (+ (get games-played player-current-stats) u1))
            })
        )
        
        (var-set match-counter match-id)
        (ok match-id)
    )
)

(define-public (verify-score (match-id uint))
    (let (
        (match (unwrap! (get-match match-id) ERR_NOT_FOUND))
        (tournament (unwrap! (get-tournament (get tournament-id match)) ERR_NOT_FOUND))
    )
        (asserts! (or 
            (is-eq tx-sender (get organizer tournament))
            (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (asserts! (not (get verified match)) ERR_ALREADY_REGISTERED)
        
        (map-set game-matches
            { match-id: match-id }
            (merge match { verified: true })
        )
        
        (ok true)
    )
)

(define-public (finalize-tournament (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) ERR_NOT_FOUND))
    )
        (asserts! (or 
            (is-eq tx-sender (get organizer tournament))
            (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (asserts! (> stacks-block-height (get end-block tournament)) ERR_TOURNAMENT_ENDED)
        (asserts! (not (get prizes-distributed tournament)) ERR_PRIZES_DISTRIBUTED)
        
        ;; Mark tournament as ended
        (map-set tournaments
            { tournament-id: tournament-id }
            (merge tournament { is-active: false })
        )
        
        (ok true)
    )
)

(define-public (distribute-prizes (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) ERR_NOT_FOUND))
        (total-prize-pool (get prize-pool tournament))
        (platform-cut (/ (* total-prize-pool (var-get platform-fee)) u10000))
        (distributable-pool (- total-prize-pool platform-cut))
        (winner-prize (/ (* distributable-pool u50) u100)) ;; 50% to winner
        (second-prize (/ (* distributable-pool u30) u100))  ;; 30% to second
        (third-prize (/ (* distributable-pool u20) u100))   ;; 20% to third
    )
        (asserts! (or 
            (is-eq tx-sender (get organizer tournament))
            (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (asserts! (not (get is-active tournament)) ERR_TOURNAMENT_ENDED)
        (asserts! (not (get prizes-distributed tournament)) ERR_PRIZES_DISTRIBUTED)
        
        ;; Set prize amounts for top 3
        (map-set tournament-rankings
            { tournament-id: tournament-id, rank: u1 }
            { player: 'SP000000000000000000002Q6VF78, score: u0, prize-amount: winner-prize }
        )
        
        (map-set tournament-rankings
            { tournament-id: tournament-id, rank: u2 }
            { player: 'SP000000000000000000002Q6VF78, score: u0, prize-amount: second-prize }
        )
        
        (map-set tournament-rankings
            { tournament-id: tournament-id, rank: u3 }
            { player: 'SP000000000000000000002Q6VF78, score: u0, prize-amount: third-prize }
        )
        
        ;; Mark prizes as distributed
        (map-set tournaments
            { tournament-id: tournament-id }
            (merge tournament { prizes-distributed: true })
        )
        
        (ok distributable-pool)
    )
)

(define-public (claim-prize (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) ERR_NOT_FOUND))
        (registration (unwrap! (get-player-registration tournament-id tx-sender) ERR_NOT_FOUND))
        (player-current-stats (get-player-stats tx-sender))
    )
        (asserts! (get prizes-distributed tournament) ERR_NOT_FOUND)
        (asserts! (not (get prize-claimed registration)) ERR_ALREADY_REGISTERED)
        (asserts! (> (get prize-won registration) u0) ERR_INVALID_SCORE)
        
        ;; Mark prize as claimed
        (map-set tournament-players
            { tournament-id: tournament-id, player: tx-sender }
            (merge registration { prize-claimed: true })
        )
        
        ;; Update player stats
        (map-set player-stats
            { player: tx-sender }
            (merge player-current-stats {
                total-winnings: (+ (get total-winnings player-current-stats) (get prize-won registration)),
                tournaments-won: (if (is-eq (get final-rank registration) u1)
                    (+ (get tournaments-won player-current-stats) u1)
                    (get tournaments-won player-current-stats))
            })
        )
        
        (ok (get prize-won registration))
    )
)

(define-public (award-achievement (player principal) (achievement-name (string-utf8 50)) (tournament-id uint))
    (let (
        (achievement-id (+ (var-get achievement-counter) u1))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        (map-set player-achievements
            { player: player, achievement-id: achievement-id }
            {
                achievement-name: achievement-name,
                earned-at: stacks-block-height,
                tournament-id: tournament-id
            }
        )
        
        (var-set achievement-counter achievement-id)
        (ok achievement-id)
    )
)

(define-public (cancel-tournament (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get organizer tournament)) ERR_UNAUTHORIZED)
        (asserts! (< stacks-block-height (get start-block tournament)) ERR_TOURNAMENT_ENDED)
        
        (map-set tournaments
            { tournament-id: tournament-id }
            (merge tournament { is-active: false })
        )
        
        (ok true)
    )
)