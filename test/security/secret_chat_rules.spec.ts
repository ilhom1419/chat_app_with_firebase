/**
 * Isolated Firebase Local Emulator Suite Tests for Secret Chat Security Rules
 * Project ID: demo-secret-chat-test
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import * as fs from "fs";
import * as path from "path";

const PROJECT_ID = "demo-secret-chat-test";

describe("Secret Chat Security Rules Tests", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    const firestoreRules = fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");
    const storageRules = fs.readFileSync(path.resolve(__dirname, "../../storage.rules"), "utf8");
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules: firestoreRules },
      storage: { rules: storageRules },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // TEST 1: Unauthenticated message creation
  test("1. Unauthenticated message creation must be rejected", async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const msgRef = unauthDb.doc("secret_chats/chat_1/messages/msg_1");
    await assertFails(
      msgRef.set({
        messageId: "msg_1",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64CiphertextBytes==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      })
    );
  });

  // TEST 2: Third-party message injection
  test("2. Non-member (Eve) cannot inject message into Alice & Bob's chat", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
    });

    const eveDb = testEnv.authenticatedContext("eve").firestore();
    const msgRef = eveDb.doc("secret_chats/chat_1/messages/msg_eve");
    await assertFails(
      msgRef.set({
        messageId: "msg_eve",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "eve",
        senderDeviceId: "dev_eve_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      })
    );
  });

  // TEST 3: Sender device impersonation
  test("3. Alice cannot send a message using an unverified senderDeviceId", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
      await context.firestore().doc("users/alice/devices/dev_alice_1").set({
        registrationId: 101,
        identityPublicKey: "AlicePublicKeyBase64LongString==",
        signedPreKey: {},
        revoked: false,
        createdAt: new Date(),
      });
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const msgRef = aliceDb.doc("secret_chats/chat_1/messages/msg_fake_dev");
    await assertFails(
      msgRef.set({
        messageId: "msg_fake_dev",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_UNKNOWN",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      })
    );
  });

  // TEST 4: Identity key replacement (Immutability)
  test("4. Alice cannot replace or modify her published identityPublicKey", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/alice/devices/dev_alice_1").set({
        registrationId: 101,
        identityPublicKey: "OriginalAliceKeyBase64String==",
        signedPreKey: {},
        revoked: false,
        createdAt: new Date(),
      });
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const devRef = aliceDb.doc("users/alice/devices/dev_alice_1");
    await assertFails(
      devRef.update({
        identityPublicKey: "MaliciousSubstitutedKeyBase64String==",
      })
    );
  });

  // TEST 5: Revoked device protection (Cannot reactivate revoked device)
  test("5. A revoked device cannot be reactivated (revoked: true -> false)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/alice/devices/dev_alice_1").set({
        registrationId: 101,
        identityPublicKey: "OriginalAliceKeyBase64String==",
        signedPreKey: {},
        revoked: true,
        createdAt: new Date(),
      });
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const devRef = aliceDb.doc("users/alice/devices/dev_alice_1");
    await assertFails(
      devRef.update({
        revoked: false,
      })
    );
  });

  // TEST 6: Message sending blocked on terminated chat
  test("6. Messages cannot be sent to a terminated chat", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "terminated",
        createdAt: new Date(),
      });
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const msgRef = aliceDb.doc("secret_chats/chat_1/messages/msg_after_term");
    await assertFails(
      msgRef.set({
        messageId: "msg_after_term",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      })
    );
  });

  // TEST 7: Plaintext fields rejection
  test("7. Message with plaintext fields (text) must be rejected", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
      await context.firestore().doc("users/alice/devices/dev_alice_1").set({
        registrationId: 101,
        identityPublicKey: "AlicePublicKeyBase64LongString==",
        signedPreKey: {},
        revoked: false,
        createdAt: new Date(),
      });
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const msgRef = aliceDb.doc("secret_chats/chat_1/messages/msg_with_plaintext");
    await assertFails(
      msgRef.set({
        messageId: "msg_with_plaintext",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        text: "Plaintext leaked message!", // FORBIDDEN FIELD
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      })
    );
  });

  // TEST 8: Sender cannot mark own message as read
  test("8. Sender (Alice) cannot set isRead: true on her own message", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
      await context.firestore().doc("secret_chats/chat_1/messages/msg_1").set({
        messageId: "msg_1",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      });
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const msgRef = aliceDb.doc("secret_chats/chat_1/messages/msg_1");
    await assertFails(
      msgRef.update({
        isRead: true,
        readAt: new Date(),
      })
    );
  });

  // TEST 9: Recipient (Bob) can mark message as read
  test("9. Recipient (Bob) can mark Alice's message as read with readAt timestamp", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
      await context.firestore().doc("secret_chats/chat_1/messages/msg_1").set({
        messageId: "msg_1",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      });
    });

    const bobDb = testEnv.authenticatedContext("bob").firestore();
    const msgRef = bobDb.doc("secret_chats/chat_1/messages/msg_1");
    await assertSucceeds(
      msgRef.update({
        isRead: true,
        readAt: new Date(),
      })
    );
  });

  // TEST 10: Non-member (Eve) cannot delete messages in Alice & Bob's chat
  test("10. Non-member (Eve) cannot delete messages in Alice & Bob's chat", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
      await context.firestore().doc("secret_chats/chat_1/messages/msg_1").set({
        messageId: "msg_1",
        chatId: "chat_1",
        protocolVersion: 1,
        envelopeType: 1,
        senderId: "alice",
        senderDeviceId: "dev_alice_1",
        recipientDeviceId: "dev_bob_1",
        payload: "Base64Payload==",
        selfDestructDuration: 5,
        createdAt: new Date(),
        isRead: false,
        readAt: null,
      });
    });

    const eveDb = testEnv.authenticatedContext("eve").firestore();
    const msgRef = eveDb.doc("secret_chats/chat_1/messages/msg_1");
    await assertFails(msgRef.delete());
  });

  // TEST 11: Storage Rules — Unauthorized user (Eve) cannot download encrypted media
  test("11. Storage Rules: Unauthorized user (Eve) cannot download Alice & Bob's media", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
    });

    const eveStorage = testEnv.authenticatedContext("eve").storage();
    const mediaRef = eveStorage.ref("secret_chats/chat_1/media/media_1");
    await assertFails(mediaRef.getBytes());
  });

  // TEST 12: Storage Rules — Unauthorized user (Eve) cannot upload media into Alice & Bob's chat
  test("12. Storage Rules: Unauthorized user (Eve) cannot upload media into Alice & Bob's chat", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
    });

    const eveStorage = testEnv.authenticatedContext("eve").storage();
    const mediaRef = eveStorage.ref("secret_chats/chat_1/media/media_1");
    await assertFails(mediaRef.put(Buffer.from("EncryptedBytes...")));
  });

  // TEST 13: Storage Rules — Overwrite/Update of existing ciphertext is forbidden (Immutable)
  test("13. Storage Rules: Overwrite/Update of encrypted media is completely forbidden", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
    });

    const aliceStorage = testEnv.authenticatedContext("alice").storage();
    const mediaRef = aliceStorage.ref("secret_chats/chat_1/media/media_1");
    await assertFails(mediaRef.updateMetadata({ customMetadata: { tampered: "true" } }));
  });

  // TEST 14: Storage Rules — Unauthorized user (Eve) cannot delete media
  test("14. Storage Rules: Non-participant (Eve) cannot delete media in Alice & Bob's chat", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
    });

    const eveStorage = testEnv.authenticatedContext("eve").storage();
    const mediaRef = eveStorage.ref("secret_chats/chat_1/media/media_1");
    await assertFails(mediaRef.delete());
  });

  // TEST 15: Storage Rules — Legitimate participant (Alice or Bob) can delete media for cleanup
  test("15. Storage Rules: Participant (Alice) can delete media upon disappearing expiration", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("secret_chats/chat_1").set({
        chatId: "chat_1",
        initiatorUid: "alice",
        initiatorDeviceId: "dev_alice_1",
        recipientUid: "bob",
        recipientDeviceId: "dev_bob_1",
        participants: ["alice", "bob"],
        selfDestructDuration: 5,
        status: "active",
        createdAt: new Date(),
      });
    });

    const aliceStorage = testEnv.authenticatedContext("alice").storage();
    const mediaRef = aliceStorage.ref("secret_chats/chat_1/media/media_1");
    // With valid chat participant membership in Firestore, delete rule allows cleanup
    await assertSucceeds(mediaRef.delete());
  });
});
