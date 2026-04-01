const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("EscrowFactory", function () {
  it("should predict the correct address", async function () {
    const [owner, depositor, payee] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("EscrowFactory");
    const factory = await Factory.deploy(owner.address);
    await factory.waitForDeployment();

    const deadline = (await time.latest()) + 3600;
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

    const deadline = (await time.latest()) + 3600;
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

  it("should revert release when signature is not from depositor", async function () {
    const [owner, depositor, payee] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("EscrowFactory");
    const factory = await Factory.deploy(owner.address);
    await factory.waitForDeployment();

    const deadline = (await time.latest()) + 3600;
    const salt = ethers.keccak256(ethers.toUtf8Bytes("invalid-signature-salt"));

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

    // Wrong signer: owner instead of depositor
    const invalidSignature = await owner.signMessage(
      ethers.getBytes(messageHash),
    );

    await expect(escrow.release(amount, invalidSignature)).to.be.revertedWith(
      "Invalid signature",
    );
  });

  it("should reclaim funds to depositor after deadline", async function () {
    const [owner, depositor, payee] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("EscrowFactory");
    const factory = await Factory.deploy(owner.address);
    await factory.waitForDeployment();

    const deadline = (await time.latest()) + 3600;
    const salt = ethers.keccak256(ethers.toUtf8Bytes("reclaim-after-deadline"));

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

    await time.increaseTo(deadline + 1);

    const depositorBalanceBefore = await ethers.provider.getBalance(
      depositor.address,
    );

    // Non-depositor caller avoids depositor gas impact in balance assertion.
    await escrow.connect(owner).reclaim();

    const depositorBalanceAfter = await ethers.provider.getBalance(
      depositor.address,
    );

    expect(depositorBalanceAfter - depositorBalanceBefore).to.equal(amount);
  });
});
