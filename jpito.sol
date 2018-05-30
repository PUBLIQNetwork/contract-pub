pragma solidity ^0.4.18;

import "./std.sol";

contract Owned_ is Owned {
    function resetOwnership() public onlyNewOwner {
        _resetOwnership();
    }
}

interface ERC20Interface_Owned {
    function totalSupply() public constant returns (uint);
    function balanceOf(address holder) public constant returns (uint);
    function transfer(address to, uint tokens) public returns (bool);
    function decimals() public constant returns (uint);
    function resetOwnership(uint royalty) public;
}

contract BCRNDH_Offer is Owned_ {
    using SafeMath for uint;
    
    uint public soft_cap;
    uint public hard_cap;
    uint public total_investment;

    uint public wave3; uint public rate3;    
    uint public wave2; uint public rate2;
    uint public wave1; uint public rate1;
    uint public deadline; uint public rate;
    

    ERC20Interface_Owned public erc20token;
    mapping(address => uint256) public investments;
    mapping(address => uint256) public tokens;
    
    bool fundingGoalReached = false;
    bool crowdsaleClosed = false;

    event GoalReached(address recipient, uint TokensRaised, uint TotalInvestment);
    event FundTransfer(address backer, uint Tokens, uint Investment);
    event Cancelation(address backer, uint Amount);

    modifier afterDeadline() { if (now >= deadline) _; }
    
    /**
     * Constrctor function
     *
     * Setup the owner
     */
    function BCRNDH_Offer(
        uint soft_cap_,
        uint durationInMinutes,
        uint tokens_per_ether,
        address erc20token_
    ) public {
        erc20token = ERC20Interface_Owned(erc20token_);
        hard_cap = erc20token.totalSupply();
        
        if (soft_cap_ == 0 || soft_cap_ >= hard_cap)
            soft_cap = hard_cap;
        else
            soft_cap = to_token(soft_cap_);

        uint duration = durationInMinutes * 1 minutes;
        
        deadline = now + duration;
        rate = to_token(tokens_per_ether);
        
        wave1 = now + duration / 5;
        rate1 = rate.mul(100 + 33).div(100);
        
        wave2 = now + duration / 3;
        rate2 = rate.mul(100 + 25).div(100);
        
        wave3 = now + duration / 2;
        rate3 = rate.mul(100 + 10).div(100);        
    }
    
    function to_token(uint value) private view returns (uint) {
        return value.mul(10**erc20token.decimals());
    }
    function claimTokenOwnership(uint royalty) public onlyOwner {
        erc20token.resetOwnership(to_token(royalty));
    }

    function tokens_raised() public view returns (uint) {
        return hard_cap.sub(erc20token.balanceOf(this));
    }
    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () public payable {
        require(!crowdsaleClosed);

        address backer = msg.sender;
        
        uint amount = msg.value;
        
        uint tok;
        if (now < wave1)
            tok = rate1;
        else if (now < wave2)
            tok = rate2;
        else if (now < wave3)
            tok = rate3;
        else if (now < deadline)
            tok = rate;
        else
            revert();
        tok = tok.mul(amount);
        tok = tok.div(1 ether);

        if (tokens_raised().add(tok) >= hard_cap) {
            tok = hard_cap.sub(tokens_raised());
        }
        
        
        tokens[backer] = tokens[backer].add(tok);
        investments[backer] = investments[backer].add(amount);
        total_investment = total_investment.add(amount);

        erc20token.transfer(backer, tok);

        FundTransfer(backer, tok, amount);
    }

    /**
     * Check if goal was reached
     *
     * Checks if the goal or time limit has been reached and ends the campaign
     */
    function checkGoalReached() public afterDeadline {
        if (tokens_raised() >= soft_cap){
            fundingGoalReached = true;
            GoalReached(owner, tokens_raised(), total_investment);
        }
        crowdsaleClosed = true;
    }

    /**
     * Withdraw the funds
     *
     * Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the beneficiary. If goal was not reached, each contributor can withdraw
     * the amount they contributed.
     */
    function safeWithdrawal() public afterDeadline {
        if (!fundingGoalReached) {
            uint amount = investments[msg.sender];
            investments[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount)) {
                    Cancelation(msg.sender, amount);
                } else {
                    revert();
                }
            }
        } else if (owner == msg.sender) {
            if (owner.send(total_investment)) {
                FundTransfer(owner, 0, total_investment);
            } else {
                //If we fail to send the funds to beneficiary, unlock funders balance
                fundingGoalReached = false;
            }
        } else
            revert();
    }
}


