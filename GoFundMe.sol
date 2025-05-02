// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Fundraising {

    // Defines a campaign with owner, goal, deadline, total raised, withdrawal status, and donation records
    struct Campaign {
        address payable owner;            
        uint goal;                        
        uint deadline;                     
        uint amountRaised;                
        bool withdrawn;                   
        bool cancelled;
        mapping(address => uint) donations; 
    }

    uint public campaignCount;                          
    mapping(uint => Campaign) private campaigns;        

    event CampaignCreated(uint campaignId, address owner, uint goal, uint deadline);
    event DonationReceived(address indexed donor, uint indexed campaignId, uint amount);
    event FundsWithdrawn(uint indexed campaignId, uint amount);
    event DonationRefunded(address indexed donor, uint indexed campaignId, uint amount);
    event DeadlineExtended(uint indexed campaignId, uint newDeadline);
    event CampaignCancelled(uint indexed campaignId, uint timestamp);
 
    modifier campaignExists(uint _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist.");
        _;
    }

    modifier onlyOwner(uint _campaignId) {
        require(msg.sender == campaigns[_campaignId].owner, "Not the campaign owner.");
        _;
    }

    modifier beforeDeadline(uint _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline passed.");
        _;
    }

    modifier afterDeadline(uint _campaignId) {
        require(block.timestamp >= campaigns[_campaignId].deadline, "Campaign still ongoing.");
        _;
    }

    modifier notCancelled(uint _campaignId) {
        require(!campaigns[_campaignId].cancelled, "Campaign has been cancelled.");
        _;
    }

    function createCampaign(uint _goal, uint _durationInDays) external {
        require(_goal > 0, "Goal must be greater than zero.");
        require(_durationInDays > 0, "Duration must be positive.");

        Campaign storage c = campaigns[campaignCount];  
        c.owner = payable(msg.sender);             
        c.goal = _goal;                               
        c.deadline = block.timestamp + (_durationInDays * 1 days); 

        emit CampaignCreated(campaignCount, msg.sender, _goal, c.deadline); 

        campaignCount++; 
    }

    function donate(uint _campaignId) external payable campaignExists(_campaignId) beforeDeadline(_campaignId) {
        require(msg.value > 0, "Donation must be greater than zero.");

        Campaign storage c = campaigns[_campaignId]; 

        c.donations[msg.sender] += msg.value;       
        c.amountRaised += msg.value;               

        emit DonationReceived(msg.sender, _campaignId, msg.value); 
    }

    // Withdraw funds after deadline if the goal was reached
    function withdraw(uint _campaignId) external campaignExists(_campaignId) onlyOwner(_campaignId) afterDeadline(_campaignId) {
        Campaign storage c = campaigns[_campaignId];

        require(c.amountRaised >= c.goal, "Goal not reached.");     
        require(!c.withdrawn, "Funds already withdrawn.");       

        uint amount = c.amountRaised;
        c.withdrawn = true;                                       
        c.owner.transfer(amount);                                  

        emit FundsWithdrawn(_campaignId, amount);               
    }

    function refund(uint _campaignId) external campaignExists(_campaignId) afterDeadline(_campaignId) {
        Campaign storage c = campaigns[_campaignId];

        require(c.amountRaised < c.goal, "Goal was reached; refunds not allowed.");

        uint donatedAmount = c.donations[msg.sender];
        require(donatedAmount > 0, "No donations to refund.");

        c.donations[msg.sender] = 0;                         
        payable(msg.sender).transfer(donatedAmount);        

        emit DonationRefunded(msg.sender, _campaignId, donatedAmount);
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

    function refundFromCancelled(uint _campaignId) external campaignExists(_campaignId) {
        Campaign storage c = campaigns[_campaignId];
        require(c.cancelled, "Campaign is not cancelled.");
        
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
        bool withdrawn,
        bool cancelled
    ) {
        Campaign storage c = campaigns[_campaignId];
        return (c.owner, c.goal, c.deadline, c.amountRaised, c.withdrawn, c.cancelled);
    }
}