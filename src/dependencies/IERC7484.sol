// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IERC7484 {

    type AttestationDataRef is address;
    type ModuleType is uint256;
    type PackedModuleTypes is uint32;
    type ResolverUID is bytes32;
    type SchemaUID is bytes32;

    struct AttestationRecord {
        uint48 time;
        uint48 expirationTime;
        uint48 revocationTime;
        PackedModuleTypes moduleTypes;
        address moduleAddress;
        address attester;
        AttestationDataRef dataPointer;
        SchemaUID schemaUid;
    }

    struct AttestationRequest {
        address moduleAddress;
        uint48 expirationTime;
        bytes data;
        ModuleType[] moduleTypes;
    }

    struct ModuleRecord {
        ResolverUID resolverUid;
        address sender;
        bytes metadata;
    }

    struct ResolverRecord {
        address resolver;
        address resolverOwner;
    }

    struct RevocationRequest {
        address moduleAddress;
    }

    struct SchemaRecord {
        uint48 registeredAt;
        address validator;
        string schema;
    }

    error AccessDenied();
    error AlreadyAttested();
    error AlreadyRegistered(address module);
    error AlreadyRevoked();
    error AttestationNotFound();
    error DifferentResolvers();
    error ExternalError_ModuleRegistration();
    error ExternalError_ResolveAttestation();
    error ExternalError_ResolveRevocation();
    error ExternalError_SchemaValidation();
    error FactoryCallFailed(address factory);
    error InsufficientAttestations();
    error InvalidAddress();
    error InvalidAttestation();
    error InvalidDeployment();
    error InvalidExpirationTime();
    error InvalidModuleType();
    error InvalidModuleTypes();
    error InvalidResolver(address resolver);
    error InvalidResolverUID(ResolverUID uid);
    error InvalidSalt();
    error InvalidSchema();
    error InvalidSchemaValidator(address validator);
    error InvalidSignature();
    error InvalidThreshold();
    error InvalidTrustedAttesterInput();
    error ModuleAddressIsNotContract(address moduleAddress);
    error ModuleNotFoundInRegistry(address module);
    error NoTrustedAttestersFound();
    error ResolverAlreadyExists();
    error RevokedAttestation(address attester);
    error SchemaAlreadyExists(SchemaUID uid);

    event Attested(address indexed moduleAddress, address indexed attester, SchemaUID schemaUID, AttestationDataRef indexed sstore2Pointer);
    event ModuleRegistration(address indexed implementation);
    event NewResolver(ResolverUID indexed uid, address indexed resolver);
    event NewResolverOwner(ResolverUID indexed uid, address newOwner);
    event NewTrustedAttesters(address indexed smartAccount);
    event ResolverRevocationError(address resolver);
    event Revoked(address indexed moduleAddress, address indexed revoker, SchemaUID schema);
    event SchemaRegistered(SchemaUID indexed uid, address indexed registerer);

    function attest(SchemaUID schemaUID, address attester, AttestationRequest[] memory requests, bytes memory signature) external;
    function attest(SchemaUID schemaUID, address attester, AttestationRequest memory request, bytes memory signature) external;
    function attest(SchemaUID schemaUID, AttestationRequest memory request) external;
    function attest(SchemaUID schemaUID, AttestationRequest[] memory requests) external;
    function attesterNonce(address attester) external view returns (uint256 nonce);
    function calcModuleAddress(bytes32 salt, bytes memory initCode) external view returns (address);
    function check(address module, address[] memory attesters, uint256 threshold) external view;
    function check(address module, ModuleType moduleType, address[] memory attesters, uint256 threshold) external view;
    function check(address module, ModuleType moduleType) external view;
    function check(address module) external view;
    function checkForAccount(address smartAccount, address module) external view;
    function checkForAccount(address smartAccount, address module, ModuleType moduleType) external view;
    function deployModule(bytes32 salt, ResolverUID resolverUID, bytes memory initCode, bytes memory metadata, bytes memory resolverContext)
        external
        payable
        returns (address moduleAddress);
    function deployViaFactory(
        address factory,
        bytes memory callOnFactory,
        bytes memory metadata,
        ResolverUID resolverUID,
        bytes memory resolverContext
    ) external payable returns (address moduleAddress);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function findAttestation(address module, address attester) external view returns (AttestationRecord memory attestation);
    function findAttestations(address module, address[] memory attesters) external view returns (AttestationRecord[] memory attestations);
    function findModule(address moduleAddress) external view returns (ModuleRecord memory moduleRecord);
    function findResolver(ResolverUID uid) external view returns (ResolverRecord memory);
    function findSchema(SchemaUID uid) external view returns (SchemaRecord memory);
    function findTrustedAttesters(address smartAccount) external view returns (address[] memory attesters);
    function getDigest(AttestationRequest memory request, address attester) external view returns (bytes32 digest);
    function getDigest(RevocationRequest[] memory requests, address attester) external view returns (bytes32 digest);
    function getDigest(RevocationRequest memory request, address attester) external view returns (bytes32 digest);
    function getDigest(AttestationRequest[] memory requests, address attester) external view returns (bytes32 digest);
    function registerModule(ResolverUID resolverUID, address moduleAddress, bytes memory metadata, bytes memory resolverContext) external;
    function registerResolver(address resolver) external returns (ResolverUID uid);
    function registerSchema(string memory schema, address validator) external returns (SchemaUID uid);
    function revoke(RevocationRequest[] memory requests) external;
    function revoke(address attester, RevocationRequest[] memory requests, bytes memory signature) external;
    function revoke(RevocationRequest memory request) external;
    function revoke(address attester, RevocationRequest memory request, bytes memory signature) external;
    function setResolver(ResolverUID uid, address resolver) external;
    function transferResolverOwnership(ResolverUID uid, address newOwner) external;
    function trustAttesters(uint8 threshold, address[] memory attesters) external;

}
