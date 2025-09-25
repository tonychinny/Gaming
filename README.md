# Gaming Tournament Platform Smart Contract

## Overview

This Clarity smart contract implements a **Play-to-Earn Gaming Tournament Platform**, enabling users to create and join tournaments, submit scores, track leaderboards, earn prizes, and unlock achievements. It supports secure registration, reward distribution, and player statistics tracking.

---

## Features

* **Tournament Management**

  * Create and cancel tournaments
  * Set entry fees, prize pools, player limits, and timeframes
  * Automatic handling of start and end blocks
* **Player Interaction**

  * Register for tournaments
  * Submit and verify scores
  * Track individual performance
* **Prizes**

  * Automatic prize pool growth via entry fees
  * Platform fee deduction
  * Distribution of prizes to top-ranked players
  * Prize claiming with stats updates
* **Leaderboards**

  * Track rankings by score and prize amounts
  * Finalize tournaments after completion
* **Achievements**

  * Award custom achievements to players
  * Store achievements with timestamps and related tournaments
* **Player Stats**

  * Track tournaments played, wins, winnings, best scores, and averages

---

## Data Structures

* **Tournaments**

  * Organizer, name, game type, entry fee, prize pool, max/current players, timeframe, status, distribution flag
* **Tournament Players**

  * Registration info, entry fee, score, rank, prize won/claimed
* **Game Matches**

  * Match details including score, duration, verification
* **Tournament Rankings**

  * Leaderboard with player ranks and prize allocations
* **Player Stats**

  * History of play, wins, winnings, and averages
* **Player Achievements**

  * Earned achievements with name, tournament, and time

---

## Key Functions

### Read-Only

* `get-tournament` – Retrieve tournament details
* `get-player-registration` – View player’s tournament data
* `get-match` – Get match details
* `get-ranking` – Get leaderboard entry
* `get-player-stats` – Fetch player statistics
* `tournament-active` – Check if tournament is active
* `registration-open` – Check if registration is open
* `get-tournament-count` – Total tournaments created

### Public

* **Tournament Lifecycle**

  * `create-tournament` – Create new tournament
  * `cancel-tournament` – Cancel before start
  * `finalize-tournament` – Close after end
* **Player Actions**

  * `register-for-tournament` – Join a tournament
  * `submit-score` – Submit match results
  * `verify-score` – Organizer/owner verifies match
  * `claim-prize` – Claim allocated prize
* **Prize Management**

  * `distribute-prizes` – Allocate rewards to winners
* **Achievements**

  * `award-achievement` – Assign achievement to player

---

## Error Codes

* `u400` – Invalid score or parameters
* `u401` – Unauthorized action
* `u402` – Insufficient entry fee
* `u403` – Tournament full
* `u404` – Not found
* `u405` – Tournament ended
* `u406` – Already registered
* `u407` – Prizes already distributed

---

## Notes

* Platform fee is deducted from prize pool (`5%`).
* Prizes default to **50% for 1st**, **30% for 2nd**, **20% for 3rd**.
* Achievements are only assignable by the **contract owner**.
