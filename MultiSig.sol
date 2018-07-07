pragma solidity ^0.4.20;

contract MultiSig {
  using SafeMath for uint256;

  // Variables
  address private contractOwner;
  bool private isContractActive;
  uint private signerCount;
  uint private contributorCount;
  uint private totalContributions;
  uint public availableContributions;
  
  mapping (address => uint) public contributionsMap;
  mapping (address => bool) public signerList;
  mapping(address => uint) _beneficiaryProposalIndex;  
  mapping (address => uint) amountToWithdraw;
  address[] contributorsList;
  Proposal[] proposals;

    struct Proposal {
        uint _valueInWei;
        address _beneficiary;
        uint approvalCount;
        uint rejectedCount;
        mapping (address => uint) sigatures;
    }

  // Constructor
  constructor () public {
    contractOwner = msg.sender;
    isContractActive = false;
    
    signerList[0xdD870fA1b7C4700F2BD7f44238821C26f7392148] = true;
    signerList[0x583031D1113aD414F02576BD6afaBfb302140225] = true;
    signerList[0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB] = true;
    signerCount = signerCount.add(3);
    
    proposals.push(Proposal(0, msg.sender, signerCount, 0));
  }

  // Events
  event ReceivedContribution(address indexed _contributor, uint _valueInWei);
  event ProposalSubmitted(address indexed _beneficiary, uint _valueInWei);
  event ProposalApproved(address indexed _approver, address indexed _beneficiary, uint _valueInWei);
  event ProposalRejected(address indexed _rejecter, address indexed _beneficiary, uint _valueInWei);
  event WithdrawPerformed(address indexed _beneficiary, uint _valueInWei);

  // Modifiers
  modifier onlyifContractStatusActive() {
    require(isContractActive == true);
    _;
  }
  modifier acceptContributions() {
    require(isContractActive == false);
    _;
  }
  modifier onlySigner() {
    require(signerList[msg.sender], "You are not a signer!!");
    _;
  }
  
  modifier onlyIfValueAllowed(uint _amount) {
        require(_amount.mul(10) <= totalContributions);
        require(_amount <= availableContributions);
     _;   
    }
    
    modifier onlyIfNoOpenProposal() {
          require(_beneficiaryProposalIndex[msg.sender] == 0 || isProposalClosed(msg.sender));
        _;
    }
    
    modifier onlyIfNotVoted(address _beneficiary) {
        require(_beneficiaryProposalIndex[_beneficiary] > 0);
        require(proposals[_beneficiaryProposalIndex[_beneficiary]].sigatures[msg.sender] == 0);
        _;
    }
    
    modifier onlyIfWithdrawable(uint _amountToWithdraw) {        
          require(amountToWithdraw[msg.sender] >= _amountToWithdraw);
        _;
    }
    
    function isProposalClosed(address _beneficiary) public view returns (bool) {
        if(proposals[_beneficiaryProposalIndex[_beneficiary]].rejectedCount > signerCount.div(2)) {
            return true;
        }
        if(proposals[_beneficiaryProposalIndex[_beneficiary]].approvalCount > signerCount.div(2)) {
            return true;
        }   
        return false;     
    }
    

function owner() external view returns(address){
  return contractOwner;
}

function () payable public acceptContributions {
  require(msg.value > 0);
   contributionsMap[msg.sender] = contributionsMap[msg.sender].add(msg.value);
   totalContributions = totalContributions.add(msg.value);
  bool alreadyExists = false;
  for(uint i = 0; i< contributorsList.length; i++){
      if(contributorsList[i] == msg.sender){
        alreadyExists = true;
      }
  }
  if(!alreadyExists){
    contributorsList.push(msg.sender);
  }
   emit ReceivedContribution(msg.sender, msg.value);
}

function endContributionPeriod() acceptContributions onlySigner external {
    require(totalContributions > 0);
    availableContributions = totalContributions;
    isContractActive = true;
}

function listContributors() external view returns (address[]) {
     return contributorsList;
}

function getContributorAmount(address _contributor) external view returns (uint) {
     return contributionsMap[_contributor];
}

function getContractStatus() external view returns (bool) {
     return isContractActive;
}

function getTotalContributions() external view returns (uint) {
     return totalContributions;
}

function submitProposal(uint _valueInWei) external onlyifContractStatusActive onlyIfNoOpenProposal onlyIfValueAllowed(_valueInWei) {
   proposals.push(Proposal(_valueInWei, msg.sender, 0, 0));
  _beneficiaryProposalIndex[msg.sender] = proposals.length - 1;
  availableContributions = availableContributions.sub(_valueInWei);
  emit ProposalSubmitted(msg.sender, _valueInWei);
}
    
function approve(address _beneficiary) external onlyifContractStatusActive onlySigner onlyIfNotVoted(_beneficiary) {
    Proposal storage p = proposals[_beneficiaryProposalIndex[_beneficiary]];
    p.sigatures[msg.sender] = 1;  
    p.approvalCount = p.approvalCount.add(1);

    if(p.approvalCount > signerCount.div(2)) {
      amountToWithdraw[_beneficiary] = amountToWithdraw[_beneficiary].add(p._valueInWei);
    }
    emit ProposalApproved(msg.sender, _beneficiary, p._valueInWei);
}
    
    function reject(address _beneficiary) external onlyifContractStatusActive onlySigner onlyIfNotVoted(_beneficiary) {
        Proposal storage p = proposals[_beneficiaryProposalIndex[_beneficiary]];
        p.sigatures[msg.sender] = 2;
        p.rejectedCount++;
        
        if(p.rejectedCount > signerCount.div(2)) {
            availableContributions = availableContributions.add(p._valueInWei);
        }
        emit ProposalRejected(msg.sender, _beneficiary, p._valueInWei);
    }
  
    function withdraw(uint _valueInWei) external onlyifContractStatusActive onlyIfWithdrawable(_valueInWei) {
        amountToWithdraw[msg.sender] = amountToWithdraw[msg.sender].sub(_valueInWei);        
        msg.sender.transfer(_valueInWei);
        emit WithdrawPerformed(msg.sender, _valueInWei);
    }
    
    function getSignerVote(address _signer, address _beneficiary) view external returns(uint) {
        return proposals[_beneficiaryProposalIndex[_beneficiary]].sigatures[_signer];
    }

function listOpenBeneficiariesProposals() external view returns (address[]) {
    address[] memory openBeneficiaries = new address[](proposals.length);
    uint j=0;
    for(uint i=1; i < proposals.length;i++) {
        Proposal storage p = proposals[i];
        if(p.rejectedCount <= signerCount.div(2) && p.approvalCount <= signerCount.div(2)) {
            openBeneficiaries[j++] = p._beneficiary;
        }
    }
    
    address[] memory openBeneficiariesActual = new address[](j);
    for(i=0;i<j;i++){
        openBeneficiariesActual[i] = openBeneficiaries[i];
    }
    
     return openBeneficiariesActual;
}

   function getBeneficiaryProposal(address _beneficiary) external view returns (uint) {
     return proposals[_beneficiaryProposalIndex[_beneficiary]]._valueInWei;
   }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}
