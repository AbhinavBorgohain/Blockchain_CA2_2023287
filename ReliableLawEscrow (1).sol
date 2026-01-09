// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  Escrow contract for legal services.
*/

contract ReliableLawEscrow {
    address public client;
    address public solicitor;
    address public arbitrator;

    uint256 public escrowAmount;

    enum Status { Created, Funded, Completed, Disputed, Paid, Refunded }
    Status public status;

    event Funded(address indexed from, uint256 amount);
    event WorkCompleted(address indexed by);
    event PaymentReleased(address indexed to, uint256 amount);
    event Refunded(address indexed to, uint256 amount);
    event DisputeOpened(address indexed by);
    event DisputeResolved(address indexed by, bool paidToSolicitor);

    modifier onlyClient() {
        require(msg.sender == client, "Only client");
        _;
    }

    modifier onlySolicitor() {
        require(msg.sender == solicitor, "Only solicitor");
        _;
    }

    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "Only arbitrator");
        _;
    }

    modifier atStatus(Status expected) {
        require(status == expected, "Wrong status");
        _;
    }

    constructor(address _client, address _solicitor, address _arbitrator) {
        require(
            _client != address(0) && _solicitor != address(0) && _arbitrator != address(0),
            "Zero address"
        );
        require(_client != _solicitor, "Client and solicitor must differ");

        client = _client;
        solicitor = _solicitor;
        arbitrator = _arbitrator;

        status = Status.Created;
    }

    // Client deposits ETH into escrow
    function fundEscrow() external payable onlyClient atStatus(Status.Created) {
        require(msg.value > 0, "Send some ETH");
        escrowAmount = msg.value;
        status = Status.Funded;
        emit Funded(msg.sender, msg.value);
    }

    // Solicitor confirms the legal service is completed
    function confirmWorkCompleted() external onlySolicitor atStatus(Status.Funded) {
        status = Status.Completed;
        emit WorkCompleted(msg.sender);
    }

    // Client releases payment after work is completed
    function releasePayment() external onlyClient atStatus(Status.Completed) {
        uint256 amount = escrowAmount;
        _pay(solicitor);
        status = Status.Paid;
        emit PaymentReleased(solicitor, amount);
    }

    // Client can refund before work is completed (while Funded)
    function refundBeforeCompletion() external onlyClient atStatus(Status.Funded) {
        uint256 amount = escrowAmount;
        _pay(client);
        status = Status.Refunded;
        emit Refunded(client, amount);
    }

    // Client can open a dispute after completion but before payment
    function openDispute() external onlyClient atStatus(Status.Completed) {
        status = Status.Disputed;
        emit DisputeOpened(msg.sender);
    }

    // Arbitrator resolves dispute: true => pay solicitor, false => refund client
    function resolveDispute(bool paySolicitor) external onlyArbitrator atStatus(Status.Disputed) {
        if (paySolicitor) {
            uint256 amount = escrowAmount;
            _pay(solicitor);
            status = Status.Paid;
            emit PaymentReleased(solicitor, amount);
        } else {
            uint256 amount = escrowAmount;
            _pay(client);
            status = Status.Refunded;
            emit Refunded(client, amount);
        }

        emit DisputeResolved(msg.sender, paySolicitor);
    }

    // internal payment helper
    function _pay(address to) internal {
        uint256 amount = escrowAmount;
        require(amount > 0, "Nothing in escrow");
        escrowAmount = 0;

        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "Transfer failed");
    }
}
