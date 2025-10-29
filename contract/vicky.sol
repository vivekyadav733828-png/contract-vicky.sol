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
