const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EscrowFactory", function () {
  it("should predict the correct address", async function () {
    const [owner, depositor, payee] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("EscrowFactory");
    const factory = await Factory.deploy(owner.address);
    await factory.waitForDeployment();

    const deadline = Math.floor(Date.now() / 1000) + 3600;
    const salt = ethers.keccak256(ethers.toUtf8Bytes("test-salt"));

    const predicted = await factory.predictAddress(
      depositor.address,
      payee.address,
      deadline,
      salt,
    );

    await factory
      .connect(depositor)
      .createEscrow(depositor.address, payee.address, deadline, salt);

    const code = await ethers.provider.getCode(predicted);
    expect(code).to.not.equal("0x");

    const actual = await factory.predictAddress(
      depositor.address,
      payee.address,
      deadline,
      salt,
    );

    expect(actual).to.equal(predicted);
  });

  it("should fund and release correctly with fee", async function () {
    const [owner, depositor, payee] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("EscrowFactory");
    const factory = await Factory.deploy(owner.address);
    await factory.waitForDeployment();

    const deadline = Math.floor(Date.now() / 1000) + 3600;
    const salt = ethers.keccak256(ethers.toUtf8Bytes("test-salt"));

    await factory
      .connect(depositor)
      .createEscrow(depositor.address, payee.address, deadline, salt);

    const escrowAddress = await factory.predictAddress(
      depositor.address,
      payee.address,
      deadline,
      salt,
    );

    const Escrow = await ethers.getContractFactory("SimpleEscrow");
    const escrow = Escrow.attach(escrowAddress);

    const amount = ethers.parseEther("1");

    await escrow.connect(depositor).fund({ value: amount });

    const messageHash = ethers.solidityPackedKeccak256(
      ["string", "address", "uint256"],
      ["RELEASE", escrowAddress, amount],
    );

    const signature = await depositor.signMessage(ethers.getBytes(messageHash));

    await escrow.release(amount, signature);

    const factoryBalance = await ethers.provider.getBalance(
      await factory.getAddress(),
    );
    expect(factoryBalance).to.equal(ethers.parseEther("0.01"));
  });
});
