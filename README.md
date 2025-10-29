# 🎟️ EventFi — Decentralized Event Ticketing on Blockchain  

> **EventFi** is a beginner-friendly decentralized application (dApp) built using **Solidity** that allows users to create, buy, and manage **event tickets** directly on the blockchain.  
> It brings transparency, security, and true ownership to event ticketing through smart contracts.

---



<img width="1920" height="1020" alt="Celo Sepolia transaction 0xc67796dbac0f0e8b8dfb3ed53f1ab1d8e0a6aea862856066fd002cc88553f65e _ Blockscout - Google Chrome 29-10-2025 13_54_06" src="https://github.com/user-attachments/assets/cf4bd5e7-b183-4f94-8aa9-6ec6f270be89" />


## 🧩 Project Description

Traditional event ticketing systems often suffer from problems like counterfeiting, hidden fees, and centralized control. **EventFi** solves these issues by providing a **trustless, transparent, and tamper-proof** platform for managing event tickets.  

With **EventFi**, event organizers can:
- Create and manage their events on-chain.  
- Sell tickets directly to users for a set price.  
- Withdraw funds safely after ticket sales.  

And users can:
- Buy tickets securely using cryptocurrency (ETH).  
- Own verifiable, immutable proof-of-purchase stored on-chain.  
- Transfer their tickets to others safely.  

---

## 💡 What It Does

**EventFi** acts as a decentralized marketplace for event tickets.  

Here’s how it works step-by-step:

1. 🏗️ **Create Event** — An organizer sets up an event (name, price, capacity, date).  
2. 💸 **Buy Ticket** — Users purchase tickets by paying the required ETH amount.  
3. 🧾 **Proof of Purchase** — Ownership details and purchase timestamps are recorded permanently on the blockchain.  
4. 🔁 **Transfer Ticket** — Ticket owners can transfer ownership to another wallet.  
5. 💰 **Withdraw Funds** — The organizer can withdraw all event proceeds safely.  

All transactions are handled by the smart contract, ensuring **no middlemen** and **no manipulation**.

---

## ✨ Features

| Feature | Description |
|----------|-------------|
| 🏗️ **Create Events** | Organizers can create events with ticket price, capacity, and date. |
| 💸 **Buy Tickets** | Users can purchase tickets using ETH — verified and recorded on-chain. |
| 🧾 **Proof-of-Purchase** | Ticket ownership and purchase time are permanently stored on the blockchain. |
| 🔁 **Transfer Tickets** | Secure ticket transfers between wallet addresses. |
| 💰 **Withdraw Earnings** | Event creators can withdraw collected funds anytime. |
| 🧾 **View Event Info** | Anyone can view event stats (tickets sold, balance, etc.). |
| 🚫 **Safe ETH Handling** | Contract rejects accidental ETH transfers with custom fallback. |

---

## 🌐 Deployed Smart Contract

**Network:** Celo Sepolia Testnet  
**Transaction / Deployment Link:**  
🔗 [View on Celo Blockscout](https://celo-sepolia.blockscout.com/tx/0xc67796dbac0f0e8b8dfb3ed53f1ab1d8e0a6aea862856066fd002cc88553f65e)

**Deployed Contract Address:** `XXX`

https://celo-sepolia.blockscout.com/tx/0xc67796dbac0f0e8b8dfb3ed53f1ab1d8e0a6aea862856066fd002cc88553f65e
---

## 💻 Smart Contract Code

Below is the Solidity code for **EventFi**:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title EventFi - Simple decentralized event ticketing (beginner friendly)
/// @author
/// @notice Create events, buy tickets (on-chain proof-of-purchase), transfer tickets, and withdraw funds.
contract EventFi {
    // --- Data structures ---

    struct EventData {
        address organizer;
        string name;
        uint256 date;         // unix timestamp for event date (optional)
        uint256 priceWei;     // ticket price in wei
        uint256 capacity;     // total tickets available
        uint256 ticketsSold;  // counter
        uint256 balance;      // collected funds for organizer (in wei)
        bool active;          // whether event is active (open for sales)
    }

    struct Ticket {
        uint256 eventId;
        address owner;
        uint256 purchasedAt; // timestamp of purchase
        bool exists;
    }

    // --- State ---
    uint256 private nextEventId = 1;
    uint256 private nextTicketId = 1;

    mapping(uint256 => EventData) public events;       // eventId => EventData
    mapping(uint256 => Ticket) public tickets;         // ticketId => Ticket
    mapping(address => uint256[]) public ticketsOf;    // owner => list of their ticketIds (helper for UI)

    // --- Events (logs) ---
    event EventCreated(uint256 indexed eventId, address indexed organizer, string name, uint256 priceWei, uint256 capacity);
    event EventClosed(uint256 indexed eventId);
    event TicketPurchased(uint256 indexed eventId, uint256 indexed ticketId, address indexed buyer, uint256 priceWei);
    event TicketTransferred(uint256 indexed ticketId, address indexed from, address indexed to);
    event Withdrawal(uint256 indexed eventId, address indexed organizer, uint256 amountWei);

    // --- Modifiers ---
    modifier onlyOrganizer(uint256 eventId) {
        require(events[eventId].organizer == msg.sender, "only organizer");
        _;
    }

    modifier eventExists(uint256 eventId) {
        require(events[eventId].organizer != address(0), "event not exist");
        _;
    }

    // --- Functions ---

    /// @notice Create a new event. Organizer becomes msg.sender.
    /// @param name Human-readable name of event
    /// @param date Unix timestamp of event date (optional, set 0 if unused)
    /// @param priceWei Ticket price (in wei)
    /// @param capacity Maximum number of tickets available
    /// @return eventId The newly created event id
    function createEvent(
        string calldata name,
        uint256 date,
        uint256 priceWei,
        uint256 capacity
    ) external returns (uint256 eventId) {
        require(capacity > 0, "capacity must be > 0");

        eventId = nextEventId++;
        events[eventId] = EventData({
            organizer: msg.sender,
            name: name,
            date: date,
            priceWei: priceWei,
            capacity: capacity,
            ticketsSold: 0,
            balance: 0,
            active: true
        });

        emit EventCreated(eventId, msg.sender, name, priceWei, capacity);
    }

    /// @notice Buy one ticket for an active event. Sends ETH equal to price.
    /// @param eventId ID of the event
    /// @return ticketId The id of the newly issued ticket
    function buyTicket(uint256 eventId) external payable eventExists(eventId) returns (uint256 ticketId) {
        EventData storage e = events[eventId];
        require(e.active, "event closed");
        require(e.ticketsSold < e.capacity, "sold out");
        require(msg.value == e.priceWei, "incorrect payment");

        // allocate ticket
        ticketId = nextTicketId++;
        tickets[ticketId] = Ticket({
            eventId: eventId,
            owner: msg.sender,
            purchasedAt: block.timestamp,
            exists: true
        });

        // bookkeeping
        e.ticketsSold += 1;
        e.balance += msg.value;
        ticketsOf[msg.sender].push(ticketId);

        emit TicketPurchased(eventId, ticketId, msg.sender, msg.value);
    }

    /// @notice Transfer a ticket you own to another address (simple on-chain transfer).
    /// @param ticketId The ticket id to transfer
    /// @param to Recipient address
    function transferTicket(uint256 ticketId, address to) external {
        require(tickets[ticketId].exists, "ticket not exist");
        require(tickets[ticketId].owner == msg.sender, "not owner");
        require(to != address(0), "invalid recipient");

        address from = msg.sender;
        tickets[ticketId].owner = to;

        // track ticketsOf (simple approach: just add to recipient's array)
        ticketsOf[to].push(ticketId);
        // Note: we do not remove from sender's ticketsOf array in this simple contract.
        // A production contract would maintain richer ownership indexing or use ERC721.

        emit TicketTransferred(ticketId, from, to);
    }

    /// @notice Check proof-of-purchase: returns owner and purchase timestamp for a ticket id
    /// @param ticketId The ticket id to check
    /// @return owner Owner address
    /// @return eventId ID of event this ticket belongs to
    /// @return purchasedAt Timestamp when it was purchased
    function getTicket(uint256 ticketId) external view returns (address owner, uint256 eventId, uint256 purchasedAt) {
        require(tickets[ticketId].exists, "ticket not exist");
        Ticket storage t = tickets[ticketId];
        return (t.owner, t.eventId, t.purchasedAt);
    }

    /// @notice Organizer withdraws collected funds for their event
    /// @param eventId The event id
    function withdrawFunds(uint256 eventId) external eventExists(eventId) onlyOrganizer(eventId) {
        EventData storage e = events[eventId];
        uint256 amount = e.balance;
        require(amount > 0, "no funds");

        // effects first
        e.balance = 0;

        // interaction (transfer)
        (bool sent, ) = e.organizer.call{value: amount}("");
        require(sent, "withdraw failed");

        emit Withdrawal(eventId, e.organizer, amount);
    }

    /// @notice Organizer can close ticket sales for their event (stop further buys)
    /// @param eventId The event id
    function closeEvent(uint256 eventId) external eventExists(eventId) onlyOrganizer(eventId) {
        events[eventId].active = false;
        emit EventClosed(eventId);
    }

    // --- Helper read functions for UI ---

    /// @notice Returns a simple summary of an event
    function getEvent(uint256 eventId) external view eventExists(eventId)
        returns (
            address organizer,
            string memory name,
            uint256 date,
            uint256 priceWei,
            uint256 capacity,
            uint256 ticketsSold,
            uint256 balance,
            bool active
        )
    {
        EventData storage e = events[eventId];
        return (e.organizer, e.name, e.date, e.priceWei, e.capacity, e.ticketsSold, e.balance, e.active);
    }

    /// @notice Returns ticket ids owned (or previously owned) by an address. Note: transfer doesn't remove ids from original holder's array in this simple implementation.
    function getTicketsOf(address owner) external view returns (uint256[] memory) {
        return ticketsOf[owner];
    }

    // --- Fallback ---
    // Prevent accidental ETH sends without calling buyTicket
    receive() external payable {
        revert("use buyTicket");
    }

    fallback() external payable {
        revert("use buyTicket");
    }
}

