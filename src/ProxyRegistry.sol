pragma solidity >=0.5.0;

import './ds-proxy/proxy.sol';

interface ICarTokenController {
    function addNewInvestors(bytes32[] calldata _keys, address[] calldata _addrs) external;
    function isInvestorAddressActive(address _addr) external view returns (bool);
}

// This Registry deploys new proxy instances through DSProxyFactory.build(address) and keeps a registry of owner => proxy
contract ProxyRegistry {
    mapping(address => DSProxy) public proxies;
    DSProxyFactory factory;

    address private _owner;

    ICarTokenController public carTokenController;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SetCarTokenController(address indexed newCarTokenController);

    modifier onlyOwner() {
        require(_owner == msg.sender, "ProxyRegistry/not-owner");
        _;
    }

    constructor(address factory_) public {
        factory = DSProxyFactory(factory_);

        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    // deploys a new proxy instance
    // sets owner of proxy to caller
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy
    function build(address owner) public returns (address payable proxy) {
        require(proxies[owner] == DSProxy(0) || proxies[owner].owner() != owner); // Not allow new proxy if the user already has one and remains being the owner
        proxy = factory.build(owner);
        proxies[owner] = DSProxy(proxy);

        if(address(carTokenController) != address(0)) {
            string memory prefix = "CSC_DS_PROXY_";

            bytes32[] memory keys = new bytes32[](1);
            keys[0] = keccak256(abi.encodePacked(prefix, proxy));

            address[] memory addresses = new address[](1);
            addresses[0] = proxy;

            if(!carTokenController.isInvestorAddressActive(proxy)){
                carTokenController.addNewInvestors(
                    keys,
                    addresses
                );
            }
        }
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "ProxyRegistry/new-owner-is-the-zero-address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function setCarTokenController(ICarTokenController _carTokenController) public onlyOwner {
        carTokenController = _carTokenController;

        emit SetCarTokenController(address(_carTokenController));
    }
}
