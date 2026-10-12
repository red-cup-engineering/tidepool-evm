// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { IMembrane } from "@red-cup-engineering/signstuff-evm/interfaces/IMembrane.sol";
import { ITidepoolMembraneV1 } from "../src/interfaces/ITidepoolMembraneV1.sol";
import { ITidepoolCharterV1 } from "../src/interfaces/ITidepoolCharterV1.sol";
import { ISleeveFactoryV1 } from "../src/interfaces/ISleeveFactoryV1.sol";
import { IMemberSleeveV1 } from "../src/interfaces/IMemberSleeveV1.sol";
import { IMembershipRegistryV1 } from "../src/interfaces/IMembershipRegistryV1.sol";
import { ITidepoolTreasuryV1 } from "../src/interfaces/ITidepoolTreasuryV1.sol";
import { ITidepoolTreasuryViewV1 } from "../src/interfaces/ITidepoolTreasuryViewV1.sol";
import { IBarrierSeriesV1 } from "../src/interfaces/IBarrierSeriesV1.sol";
import { ITallyLedgerV1 } from "../src/interfaces/ITallyLedgerV1.sol";
import { IFloatDeskV1 } from "../src/interfaces/IFloatDeskV1.sol";
import { IWithdrawalAllocatorV1 } from "../src/interfaces/IWithdrawalAllocatorV1.sol";
import { ISiteWitnessV1 } from "../src/interfaces/ISiteWitnessV1.sol";
import { IReseedMutualV1 } from "../src/interfaces/IReseedMutualV1.sol";
import { IClearinghouseV1 } from "../src/interfaces/IClearinghouseV1.sol";

/// @notice Appendix A interfaces exist, compile, and are distinct. Later tasks implement them; the selector
///         scan (`liquidat|seize|slash|sweep` except `sweepSurplus`) over compiled ABIs is TP-EVM-015.
contract InterfacesTest is Test {
    function test_interfaceIdsAreDistinct() public pure {
        bytes4[13] memory ids = [
            type(ITidepoolMembraneV1).interfaceId,
            type(ISleeveFactoryV1).interfaceId,
            type(IMemberSleeveV1).interfaceId,
            type(IMembershipRegistryV1).interfaceId,
            type(ITidepoolTreasuryV1).interfaceId,
            type(ITidepoolTreasuryViewV1).interfaceId,
            type(IBarrierSeriesV1).interfaceId,
            type(ITallyLedgerV1).interfaceId,
            type(IFloatDeskV1).interfaceId,
            type(IWithdrawalAllocatorV1).interfaceId,
            type(ISiteWitnessV1).interfaceId,
            type(IReseedMutualV1).interfaceId,
            type(IClearinghouseV1).interfaceId
        ];
        for (uint256 i; i < ids.length; ++i) {
            assertTrue(ids[i] != bytes4(0));
            for (uint256 j = i + 1; j < ids.length; ++j) assertTrue(ids[i] != ids[j]);
        }
        assertTrue(type(ITidepoolCharterV1).interfaceId != bytes4(0));
    }

    /// @dev The membrane interface extends signstuff-evm's IMembrane: `admits` is part of its selector set.
    function test_membraneExtendsIMembrane() public pure {
        ITidepoolMembraneV1 m = ITidepoolMembraneV1(address(0xBEEF));
        IMembrane asMembrane = m; // compiles only if the interface extends IMembrane
        assertEq(address(asMembrane), address(m));
        assertEq(IMembrane.admits.selector, bytes4(keccak256("admits(address,bytes32,uint8,bool)")));
        assertEq(ITidepoolMembraneV1.isSealed.selector, bytes4(keccak256("isSealed()")));
    }

    function test_clearinghouseHasNoTransferEntryPoint() public pure {
        // A.12: no function in IClearinghouseV1 moves assets; its whole selector set is the eight below.
        bytes4 all = IClearinghouseV1.open.selector ^ IClearinghouseV1.admit.selector ^ IClearinghouseV1.clear.selector
            ^ IClearinghouseV1.edgeOf.selector ^ IClearinghouseV1.netPosition.selector;
        assertEq(type(IClearinghouseV1).interfaceId, all);
    }
}
