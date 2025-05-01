// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Fundraising {

    // Defines a campaign with owner, goal, deadline, total raised, withdrawal status, and donation records
    struct Campaign {
        address payable owner;             // Creator of the campaign (can withdraw if successful)
        uint goal;                         // Goal amount in wei
        uint deadline;                     // Deadline as a UNIX timestamp
        uint amountRaised;                // Total amount raised by donations
        bool withdrawn;                    // Indicates whether funds have already been withdrawn
        bool cancelled;
        mapping(address => uint) donations; // Tracks donation amount per donor
    }

    uint public campaignCount;                          // Auto-incremented campaign ID counter
    mapping(uint => Campaign) private campaigns;        // Maps campaign ID to Campaign struct

    // Events to log blockchain activity for transparency and UI tracking
    event CampaignCreated(uint campaignId, address owner, uint goal, uint deadline);
    event DonationReceived(address indexed donor, uint indexed campaignId, uint amount);
    event FundsWithdrawn(uint indexed campaignId, uint amount);
    event DonationRefunded(address indexed donor, uint indexed campaignId, uint amount);
    event DeadlineExtended(uint indexed campaignId, uint newDeadline);
    event CampaignCancelled(uint indexed campaignId, uint timestamp);
 
    // Modifier: Checks if the campaign exists
    modifier campaignExists(uint _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist.");
        _;
    }

    // Modifier: Ensures only the campaign owner can call certain functions
    modifier onlyOwner(uint _campaignId) {
        require(msg.sender == campaigns[_campaignId].owner, "Not the campaign owner.");
        _;
    }

    // Modifier: Ensures function is called before campaign deadline
    modifier beforeDeadline(uint _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline passed.");
        _;
    }

    // Modifier: Ensures function is called after campaign deadline
    modifier afterDeadline(uint _campaignId) {
        require(block.timestamp >= campaigns[_campaignId].deadline, "Campaign still ongoing.");
        _;
    }

    modifier notCancelled(uint _campaignId) {
        require(!campaigns[_campaignId].cancelled, "Campaign has been cancelled.");
        _;
    }

    // Creates a new fundraising campaign
    function createCampaign(uint _goal, uint _durationInDays) external {
        require(_goal > 0, "Goal must be greater than zero.");
        require(_durationInDays > 0, "Duration must be positive.");

        Campaign storage c = campaigns[campaignCount];  // Get the next available campaign slot
        c.owner = payable(msg.sender);                  // Set the campaign creator
        c.goal = _goal;                                 // Set the funding goal
        c.deadline = block.timestamp + (_durationInDays * 1 days);  // Set deadline in seconds

        emit CampaignCreated(campaignCount, msg.sender, _goal, c.deadline); // Log creation

        campaignCount++; // Increment campaign ID counter
    }

    // Donate to a specific campaign
    function donate(uint _campaignId) external payable campaignExists(_campaignId) beforeDeadline(_campaignId) {
        require(msg.value > 0, "Donation must be greater than zero.");

        Campaign storage c = campaigns[_campaignId]; // Get the campaign

        c.donations[msg.sender] += msg.value;       // Track the donor's total donation
        c.amountRaised += msg.value;                // Update total raised amount

        emit DonationReceived(msg.sender, _campaignId, msg.value); // Log donation
    }

    // Withdraw funds after deadline if the goal was reached
    function withdraw(uint _campaignId) external campaignExists(_campaignId) onlyOwner(_campaignId) afterDeadline(_campaignId) {
        Campaign storage c = campaigns[_campaignId];

        require(c.amountRaised >= c.goal, "Goal not reached.");     // Ensure goal met
        require(!c.withdrawn, "Funds already withdrawn.");          // Prevent multiple withdrawals

        uint amount = c.amountRaised;
        c.withdrawn = true;                                         // Mark as withdrawn
        c.owner.transfer(amount);                                   // Transfer funds to owner

        emit FundsWithdrawn(_campaignId, amount);                   // Log withdrawal
    }

    // Refund donations if campaign fails to meet its goal after deadline
    function refund(uint _campaignId) external campaignExists(_campaignId) afterDeadline(_campaignId) {
        Campaign storage c = campaigns[_campaignId];

        require(c.amountRaised < c.goal, "Goal was reached; refunds not allowed."); // Only if failed

        uint donatedAmount = c.donations[msg.sender];
        require(donatedAmount > 0, "No donations to refund."); // Must have donated

        c.donations[msg.sender] = 0;                          // Reset before transfer (protects from reentrancy)
        payable(msg.sender).transfer(donatedAmount);          // Refund donation

        emit DonationRefunded(msg.sender, _campaignId, donatedAmount); // Log refund
    }

    function extendDeadline(uint _campaignId, uint _additionalDays) external campaignExists(_campaignId) onlyOwner(_campaignId) beforeDeadline(_campaignId) {
        require(_additionalDays > 0, "Must extend by at least 1 day");

        Campaign storage c = campaigns[_campaignId];
        c.deadline += _additionalDays * 1 days;

        emit DeadlineExtended(_campaignId, c.deadline);
    }

    function cancelCampaign(uint _campaignId) external campaignExists(_campaignId) onlyOwner(_campaignId) beforeDeadline(_campaignId) notCancelled(_campaignId) {
        Campaign storage c = campaigns[_campaignId];
        
        require(!c.withdrawn, "Funds already withdrawn.");
        require(c.amountRaised <= c.goal, "Cannot cancel a campaign that has reached its goal.");
        
        c.cancelled = true;
        
        emit CampaignCancelled(_campaignId, block.timestamp);
    }

        function refundFromCanceled(uint _campaignId) external campaignExists(_campaignId) {
        Campaign storage c = campaigns[_campaignId];
        
        require(c.cancelled, "Campaign is not canceled.");
        
        uint donatedAmount = c.donations[msg.sender];
        require(donatedAmount > 0, "No donations to refund.");
        
        c.donations[msg.sender] = 0;                          
        payable(msg.sender).transfer(donatedAmount);         
        
        emit DonationRefunded(msg.sender, _campaignId, donatedAmount);
    }

    // Public getter for campaign data (for frontend or transparency)
    function getCampaign(uint _campaignId) external view campaignExists(_campaignId) returns (
        address owner,
        uint goal,
        uint deadline,
        uint amountRaised,
        bool withdrawn
    ) {
        Campaign storage c = campaigns[_campaignId];
        return (c.owner, c.goal, c.deadline, c.amountRaised, c.withdrawn);
    }
}