package org.folio.rest.support.kafka;

import java.util.Collection;
import java.util.List;
import java.util.stream.Collectors;

import org.folio.rest.support.messages.EventMessage;

import io.vertx.core.Vertx;
import io.vertx.core.json.JsonObject;
import io.vertx.kafka.client.consumer.KafkaConsumerRecord;

public final class FakeKafkaConsumer {
  // These definitions are deliberately separate to the production definitions
  // This is so these can be changed independently to demonstrate
  // tests failing for the right reason prior to changing the production code
  final static String INSTANCE_TOPIC_NAME = "folio.test_tenant.inventory.instance";
  final static String HOLDINGS_TOPIC_NAME = "folio.test_tenant.inventory.holdings-record";
  final static String ITEM_TOPIC_NAME = "folio.test_tenant.inventory.item";
  final static String AUTHORITY_TOPIC_NAME = "folio.test_tenant.inventory.authority";
  final static String BOUND_WITH_TOPIC_NAME = "folio.test_tenant.inventory.bound-with";

  private final static MessageCollectingTopicConsumer instanceTopicConsumer = new MessageCollectingTopicConsumer(
    INSTANCE_TOPIC_NAME, KafkaConsumerRecord::key);
  private final static MessageCollectingTopicConsumer holdingsTopicConsumer = new MessageCollectingTopicConsumer(
    HOLDINGS_TOPIC_NAME, FakeKafkaConsumer::instanceAndIdKey);
  private final static MessageCollectingTopicConsumer itemTopicConsumer = new MessageCollectingTopicConsumer(
    ITEM_TOPIC_NAME, FakeKafkaConsumer::instanceAndIdKey);
  private final static MessageCollectingTopicConsumer authorityTopicConsumer = new MessageCollectingTopicConsumer(
    AUTHORITY_TOPIC_NAME, KafkaConsumerRecord::key);
  private final static MessageCollectingTopicConsumer boundWithTopicConsumer = new MessageCollectingTopicConsumer(
    BOUND_WITH_TOPIC_NAME, KafkaConsumerRecord::key);

  public FakeKafkaConsumer consume(Vertx vertx) {
    instanceTopicConsumer.subscribe(vertx);
    holdingsTopicConsumer.subscribe(vertx);
    itemTopicConsumer.subscribe(vertx);
    authorityTopicConsumer.subscribe(vertx);
    boundWithTopicConsumer.subscribe(vertx);

    return this;
  }

  public void unsubscribe() {
    instanceTopicConsumer.unsubscribe();
    holdingsTopicConsumer.unsubscribe();
    itemTopicConsumer.unsubscribe();
    authorityTopicConsumer.unsubscribe();
    boundWithTopicConsumer.unsubscribe();
  }

  public static void discardAllMessages() {
    itemTopicConsumer.discardCollectedMessages();
    instanceTopicConsumer.discardCollectedMessages();
    holdingsTopicConsumer.discardCollectedMessages();
    authorityTopicConsumer.discardCollectedMessages();
    boundWithTopicConsumer.discardCollectedMessages();
  }

  public static int getAllPublishedAuthoritiesCount() {
    return authorityTopicConsumer.countOfReceivedKeys();
  }

  public static Collection<EventMessage> getMessagesForAuthority(String authorityId) {
    return authorityTopicConsumer.receivedMessagesByKey(authorityId);
  }

  public static int getAllPublishedInstanceIdsCount() {
    return instanceTopicConsumer.countOfReceivedKeys();
  }

  public static Collection<EventMessage> getMessagesForInstance(String instanceId) {
    return instanceTopicConsumer.receivedMessagesByKey(instanceId);
  }

  public static Collection<EventMessage> getMessagesForInstances(List<String> instanceIds) {
    return instanceIds.stream()
      .map(FakeKafkaConsumer::getMessagesForInstance)
      .flatMap(Collection::stream)
      .collect(Collectors.toList());
  }

  public static Collection<EventMessage> getMessagesForHoldings(
    String instanceId, String holdingsId) {

    return holdingsTopicConsumer.receivedMessagesByKey(instanceAndIdKey(instanceId, holdingsId));
  }

  public static Collection<EventMessage> getMessagesForItem(
    String instanceId, String itemId) {

    return itemTopicConsumer.receivedMessagesByKey(instanceAndIdKey(instanceId, itemId));
  }

  public static Collection<EventMessage> getMessagesForBoundWith(String instanceId) {
    return boundWithTopicConsumer.receivedMessagesByKey(instanceId);
  }

  private static String instanceAndIdKey(String instanceId, String itemId) {
    return instanceId + "_" + itemId;
  }

  private static String instanceAndIdKey(KafkaConsumerRecord<String, JsonObject> message) {
    final JsonObject payload = message.value();
    final var oldOrNew = payload.containsKey("new")
      ? payload.getJsonObject("new") : payload.getJsonObject("old");

    final var id = oldOrNew != null ? oldOrNew.getString("id") : null;

    return instanceAndIdKey(message.key(), id);
  }
}
