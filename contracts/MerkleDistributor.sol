// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.6.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "./IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor {

    
    address public immutable override token;  
    address public immutable override owner;
    //merkleroot
    mapping(uint256 => mapping(uint256 => bytes32)) private merkleRoot;
    // This is a packed array of booleans.
    mapping(bytes32 => mapping(uint256 => uint256)) private claimedBitMap;
    
    constructor(address token_, uint256 syt_id_, uint256 epoch_, bytes32 merkleRoot_) public {
        owner = msg.sender;
        token = token_;
        merkleRoot[syt_id_][epoch_] = merkleRoot_;
    }

    function getMerkleRoot(uint256 syt_id_, uint256 epoch_) public view override returns (bytes32) {
        return merkleRoot[syt_id_][epoch_];
    }

    function setMerkleRoot(uint256 syt_id_, uint256 epoch_, bytes32 merkleRoot_) external override{
        require(msg.sender == owner, "MerkleDistributor: Only owner can call this function");
        merkleRoot[syt_id_][epoch_] = merkleRoot_;
    }

    function isClaimed(uint256 index, bytes32 merkleRoot_) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[merkleRoot_][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index, bytes32 merkleRoot_) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[merkleRoot_][claimedWordIndex] = claimedBitMap[merkleRoot_][claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, bytes32 merkleRoot_) external override {
        require(!isClaimed(index, merkleRoot_), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot_, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index, merkleRoot_);
        require(IERC20(token).transfer(account, amount), 'MerkleDistributor: Transfer failed.');

        // specific emit emision? i.e do we add syt_id 
        emit Claimed(index, account, amount);
    }
}