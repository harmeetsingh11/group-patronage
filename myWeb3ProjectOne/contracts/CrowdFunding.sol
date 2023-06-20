// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

error CrowdFunding__lessEthSent();
error CrowdFunding__donationsFailed();
error CrowdFunding__campaignDeadlineReached();
error CrowdFunding__campaignNotFound();

contract CrowdFunding {
    struct Campaign {
        address owner;
         string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => uint256) public amountWithdrawn;

    uint256 public numberOfCampaigns = 0;

    // Events
    event campaignCreated(uint256 indexed id, address indexed owner);
    event donationMade(address indexed donator, address indexed receiver, uint256 indexed amount);
    event fundsWithdrawn(uint256 indexed id, address indexed owner, uint256 amount);

    function createCampaign(
        address _owner,
        string memory _title,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image
    ) public returns (uint256) {
        uint256 campaignIdx = numberOfCampaigns;
        numberOfCampaigns++;

        Campaign storage campaign = campaigns[campaignIdx];

        require(
            _deadline > (block.timestamp * 1000),   // _deadline is in ms, while block.timestamp is in seconds
            'The deadline should be a date in the future.'
        );

        campaign.owner = _owner;
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;

        emit campaignCreated(campaignIdx, _owner);

        return campaignIdx;
    }

    function donateToCampaign(uint256 _id) public payable {
        if (_id >= numberOfCampaigns) {
            revert CrowdFunding__campaignNotFound();
        }

        uint256 amount = msg.value;

        if (amount == 0) {
            revert CrowdFunding__lessEthSent();
        }

        Campaign storage campaign = campaigns[_id];

        if (msg.sender == campaign.owner) {
            revert CrowdFunding__donationsFailed();
        }
        
        if ((block.timestamp * 1000) > campaign.deadline) {
            revert CrowdFunding__campaignDeadlineReached();
        }

        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);

        (bool sent, ) = payable(campaign.owner).call{value: amount}('');

        if (sent) {
            campaign.amountCollected += amount;
            emit donationMade(msg.sender, campaign.owner, amount);
        }
        else {
            revert CrowdFunding__donationsFailed();
        }
    }

    function withdrawFunds(uint256 _id) public {
        require(_id < numberOfCampaigns, 'Invalid campaign ID');
        Campaign storage campaign = campaigns[_id];

        require(msg.sender == campaign.owner, 'Only the campaign owner can withdraw funds');
        require((block.timestamp * 1000) > campaign.deadline, 'Campaign deadline not reached');

        uint256 amountToWithdraw = campaign.amountCollected - amountWithdrawn[_id];
        require(amountToWithdraw > 0, 'No funds available for withdrawal');

        amountWithdrawn[_id] += amountToWithdraw;

        (bool sent, ) = payable(campaign.owner).call{value: amountToWithdraw}('');
        require(sent, 'Failed to send funds to the campaign owner');

        emit fundsWithdrawn(_id, campaign.owner, amountToWithdraw);
    }

    function getDonators(uint256 _id) public view returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);
         
           Campaign storage item; 
                 
        for (uint i = 0; i < numberOfCampaigns; i++) {
            item = campaigns[i];

            allCampaigns[i] = item;
        }

        return allCampaigns;
    }
}
