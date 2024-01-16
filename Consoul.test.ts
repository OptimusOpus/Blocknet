/* eslint-disable no-unused-vars */
/* eslint-disable node/no-unpublished-import */
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect, assert } from 'chai';
import { constants, BigNumber } from 'ethers';
import { ethers } from 'hardhat';

// eslint-disable-next-line node/no-missing-import
import type { Consul, Consul__factory } from '../typechain-types/contracts';

describe('Consul', () => {
  let consul: Consul;
  let owner: SignerWithAddress;
  let controller: SignerWithAddress;
  let newOwner: SignerWithAddress;
  let nonOwner: SignerWithAddress;
  let others: SignerWithAddress[];

  const OWNER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('OWNER_ROLE')
  );
  const CONTROLLER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes('CONTROLLER_ROLE')
  );

  const newPraetor = {
    id: ethers.utils.id('New Praetor'),
    server: { ip: '1.2.3.4', port: 8080, ens: 'test.eth' },
    node: { ip: '1.2.3.4', port: 30303 },
  };

  function hexToBytesArray(hex: string): string[] {
    const bytesArray = [];
    for (let i = 0; i < hex.length; i += 2) {
      bytesArray.push('0x' + hex.slice(i, i + 2));
    }
    return bytesArray;
  }

  const helloWorldHexString = '7072696e74282848656c6c6f2c20576f726c642129'; // Replace this with the output from the Python script
  const helloWorldBytesArray = hexToBytesArray(helloWorldHexString);

  beforeEach(async () => {
    [owner, controller, newOwner, ...others] = await ethers.getSigners();
    nonOwner = others[0];
    const ConsulFactory = (await ethers.getContractFactory(
      'Consul',
      owner
    )) as Consul__factory;
    consul = await ConsulFactory.deploy();
    await consul.deployed();

    // Grant controller role
    await consul.grantRole(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes('CONTROLLER_ROLE')),
      controller.address
    );
  });

  describe('initialize', () => {
    it('should set the owner role', async () => {
      expect(await consul.hasRole(OWNER_ROLE, owner.address)).to.be.true;
    });

    it('should set the owner role as admin for itself', async () => {
      expect(await consul.getRoleAdmin(OWNER_ROLE)).to.equal(OWNER_ROLE);
    });

    it('should set the owner role as admin for controller role', async () => {
      const CONTROLLER_ROLE = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('CONTROLLER_ROLE')
      );
      expect(await consul.getRoleAdmin(CONTROLLER_ROLE)).to.equal(OWNER_ROLE);
    });
  });

  describe('transferOwnership', () => {
    it('should transfer ownership to a new address', async () => {
      await consul.transferOwnership(newOwner.address);

      expect(await consul.hasRole(OWNER_ROLE, newOwner.address)).to.be.true;
      expect(await consul.hasRole(OWNER_ROLE, owner.address)).to.be.false;
    });

    it('should revert if called by non-owner', async () => {
      await expect(
        consul.connect(others[0]).transferOwnership(newOwner.address)
      ).to.be.revertedWith('Address does not have owner permission');
    });
  });

  describe('Only Owner functions', () => {
    it('should revert if non-owner tries to add a praetor', async () => {
      await expect(
        consul
          .connect(nonOwner)
          .addPraetor(
            newPraetor.id,
            newPraetor.server.ip,
            newPraetor.server.port,
            newPraetor.server.ens,
            newPraetor.node.ip,
            newPraetor.node.port
          )
      ).to.be.revertedWith('Address does not have owner permission');
    });

    it('should revert if non-owner tries to remove a praetor', async () => {
      await expect(
        consul.connect(nonOwner).removePraetor(0)
      ).to.be.revertedWith('Address does not have owner permission');
    });

    it('should revert if non-owner tries to deactivate a praetor', async () => {
      await expect(
        consul.connect(nonOwner).deactivatePraetor(0)
      ).to.be.revertedWith('Address does not have owner permission');
    });

    it('should revert if non-owner tries to toggle dictator mode', async () => {
      await expect(
        consul.connect(nonOwner).toggleDictatorMode()
      ).to.be.revertedWith('Address does not have owner permission');
    });

    it('should revert if non-owner tries to remove a payload', async () => {
      const payloadId = ethers.utils.id('Test Payload');
      await consul.connect(owner).addPayload(payloadId, ['0x1234']);
      await expect(
        consul.connect(nonOwner).removePayload(payloadId)
      ).to.be.revertedWith('Address does not have owner permission');
    });
  });

  describe('addPraetor', function () {
    it('should add a new praetor', async function () {
      await consul.addPraetor(
        newPraetor.id,
        newPraetor.server.ip,
        newPraetor.server.port,
        newPraetor.server.ens,
        newPraetor.node.ip,
        newPraetor.node.port
      );

      const praetors = await consul.getPraetors();
      expect(praetors.length).to.equal(1);
      expect(praetors[0].id).to.equal(newPraetor.id);
      expect(praetors[0].server.ip).to.equal(newPraetor.server.ip);
      expect(praetors[0].server.port).to.equal(newPraetor.server.port);
      expect(praetors[0].node.ip).to.equal(newPraetor.node.ip);
      expect(praetors[0].node.port).to.equal(newPraetor.node.port);
      expect(praetors[0].active).to.be.true;
    });
  });

  describe('removePraetor', function () {
    it('should remove a praetor by index', async function () {
      await consul.addPraetor(
        newPraetor.id,
        newPraetor.server.ip,
        newPraetor.server.port,
        newPraetor.server.ens,
        newPraetor.node.ip,
        newPraetor.node.port
      );
      await consul.removePraetor(0);

      const praetors = await consul.getPraetors();
      expect(praetors.length).to.equal(1);
      expect(praetors[0].id).to.equal(ethers.constants.HashZero);
    });
  });

  describe('changeCommand', () => {
    it('should change command when called by a controller', async () => {
      const newCommand = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('NEW_COMMAND')
      );
      await consul.connect(controller).changeCommand(newCommand);
      expect(await consul.getCurrentCommand()).to.equal(newCommand);
    });

    it('should revert when called by a non-controller', async () => {
      const newCommand = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('NEW_COMMAND')
      );
      await expect(
        consul.connect(nonOwner).changeCommand(newCommand)
      ).to.be.revertedWith('Address does not have controller permission');
    });
  });

  describe('getCurrentCommand', () => {
    it('should return current command', async () => {
      const currentCommand = await consul.getCurrentCommand();
      expect(currentCommand).to.equal(
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes('REPORT'))
      );
    });
  });

  describe('getDictatorMode', () => {
    it('should return dictator mode status', async () => {
      const dictatorMode = await consul.getDictatorMode();
      expect(dictatorMode).to.be.false;
    });
  });

  describe('toggleDictatorMode', () => {
    it('should toggle dictator mode when called by owner', async () => {
      await consul.toggleDictatorMode();
      expect(await consul.getDictatorMode()).to.be.true;

      await consul.toggleDictatorMode();
      expect(await consul.getDictatorMode()).to.be.false;
    });

    it('should revert when called by a non-owner', async () => {
      await expect(
        consul.connect(nonOwner).toggleDictatorMode()
      ).to.be.revertedWith('Address does not have owner permission');
    });
  });

  describe('getPayload, addPayload, removePayload', () => {
    const payloadId = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes('PAYLOAD_1')
    );
    const testPayload: string[] = ['0x1234', '0x5678', '0x9abc'];

    it('should add payload when called by a controller', async () => {
      await consul.connect(controller).addPayload(payloadId, testPayload);
      const retrievedPayload = await consul.getPayload(payloadId);
      expect(retrievedPayload).to.deep.equal(testPayload);
    });

    it('should revert when addPayload is called by a non-controller', async () => {
      await expect(
        consul.connect(nonOwner).addPayload(payloadId, testPayload)
      ).to.be.revertedWith('Address does not have controller permission');
    });

    it('should revert when trying to overwrite an existing payload', async () => {
      await consul.connect(controller).addPayload(payloadId, testPayload);
      await expect(
        consul.connect(controller).addPayload(payloadId, testPayload)
      ).to.be.revertedWith('Payload already exists');
    });

    it('should remove payload when called by owner', async () => {
      await consul.connect(controller).addPayload(payloadId, testPayload);
      await consul.removePayload(payloadId);
      const retrievedPayload = await consul.getPayload(payloadId);
      expect(retrievedPayload.length).to.equal(0);
    });

    it('should revert when removePayload is called by a non-owner', async () => {
      await consul.connect(controller).addPayload(payloadId, testPayload);
      await expect(
        consul.connect(nonOwner).removePayload(payloadId)
      ).to.be.revertedWith('Address does not have owner permission');
    });

    it('should add hello world python script payload when called by a controller', async () => {
      await consul
        .connect(controller)
        .addPayload(payloadId, helloWorldBytesArray);
      const retrievedPayload = await consul.getPayload(payloadId);
      expect(retrievedPayload).to.deep.equal(helloWorldBytesArray);
    });
  });
});
