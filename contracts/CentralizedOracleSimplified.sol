// CentralizedOracle2.sol

pragma solidity 0.5.16;

library SafeMath {

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function max(int256 a, int256 b) internal pure returns (uint256) {
        return a > b ? uint256(a) : uint256(b);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256 c) {
        if (b > 0) {
            c = a - b;
            assert(c <= a);
        } else {
            c = a - b;
            assert(c >= a);
        }

    }
}
contract IReceiverStorage {
  function retrieveData(uint256 _requestId, uint256 _timestamp) public view returns(bool, uint256);
}

contract CentralizedOracle {
  using SafeMath for uint256;

  IReceiverStorage public receiverStorage;

  mapping (uint256 => mapping(uint256 => uint256)) public values;
  mapping (uint256 => mapping(uint256 => bool)) public set;
  mapping (uint256 => mapping(uint256 => bool)) public locked;
  mapping (uint256 => mapping(uint256 => bool)) public isDisputed;
  mapping(uint256 => uint256[]) public timestamps;
  mapping (uint256 => Metadata) public metadata;
  uint256 datasetCount;
  address owner;
  address oracle;

  struct Metadata {
    uint256 referenceRequestId;     // ID of corresponding mainnet data
    uint256 timestampWindow;        // Max distance from which a challenge datapoint applies to a centralized datapoint
    uint256 valueWindow;            // Min distance from which a decentralized value knocks out a centralized value
  }

  constructor(address _receiverStorage, address _owner, address _oracle) public {
      receiverStorage = IReceiverStorage(_receiverStorage);
      owner = _owner;
      oracle = _oracle;
      datasetCount=0;
  }

  function newDataset(
      uint256 _referenceRequestId,
      uint256 _timestampWindow,
      uint256 _valueWindow)
      public {
      require(msg.sender == owner);

      metadata[datasetCount] = Metadata({
          referenceRequestId: _referenceRequestId,
          timestampWindow: _timestampWindow,
          valueWindow: _valueWindow
      });

      datasetCount++;
  }

  function submitData(uint256 _requestId, uint256 _timestamp, uint256 _value) public {
      require(msg.sender == oracle);
      require(!locked[_requestId][_timestamp]);

      values[_requestId][_timestamp] = _value;
      timestamps[_requestId].push(_timestamp);
      set[_requestId][_timestamp] = true;
  }

  function challengeData(uint256 _requestId, uint256 _timestamp, uint256 _challengeTimestamp) public {
      require(set[_requestId][_timestamp]);
    //   require(_challengeTimestamp - _timestamp <= metadata[_requestId].timestampWindow);            // SafeMath
      require(_challengeTimestamp.max(_timestamp).sub(_challengeTimestamp.min(_timestamp)) <= metadata[_requestId].timestampWindow);

      (bool retrieved, uint256 retrievedValue) = receiverStorage.retrieveData(metadata[_requestId].referenceRequestId, _challengeTimestamp);
      require(retrieved);
      require(retrievedValue - values[_requestId][_timestamp] > metadata[_requestId].valueWindow);  // SafeMath
      require(retrievedValue.max(values[_requestId][_timestamp]).sub(retrievedValue.min(values[_requestId][_timestamp])) > metadata[_requestId].valueWindow);
      locked[_requestId][_timestamp] = true;
      values[_requestId][_timestamp] = retrievedValue;
  }
}
