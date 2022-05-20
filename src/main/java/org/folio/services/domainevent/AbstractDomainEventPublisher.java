package org.folio.services.domainevent;

import static io.vertx.core.Future.succeededFuture;
import static java.util.Collections.singletonList;
import static java.util.stream.Collectors.toList;
import static java.util.stream.Collectors.toMap;
import static org.apache.logging.log4j.LogManager.getLogger;
import static org.folio.rest.support.ResponseUtil.isCreateSuccessResponse;
import static org.folio.rest.support.ResponseUtil.isDeleteSuccessResponse;
import static org.folio.rest.support.ResponseUtil.isUpdateSuccessResponse;

import io.vertx.core.Future;
import io.vertx.core.Handler;
import java.util.Collection;
import java.util.List;
import javax.ws.rs.core.Response;
import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;
import org.apache.commons.lang3.tuple.Pair;
import org.apache.commons.lang3.tuple.Triple;
import org.apache.logging.log4j.Logger;
import org.folio.persist.AbstractRepository;
import org.folio.rest.support.CollectionUtil;
import org.folio.services.batch.BatchOperationContext;

abstract class AbstractDomainEventPublisher<DomainType, EventType> {
  private static final Logger log = getLogger(AbstractDomainEventPublisher.class);

  protected final AbstractRepository<DomainType> repository;
  protected final CommonDomainEventPublisher<EventType> domainEventService;

  public AbstractDomainEventPublisher(AbstractRepository<DomainType> repository,
    CommonDomainEventPublisher<EventType> domainEventService) {

    this.repository = repository;
    this.domainEventService = domainEventService;
  }

  public Handler<Response> publishUpdated(DomainType oldRecord) {
    return response -> {
      if (!isUpdateSuccessResponse(response)) {
        log.warn("Record update failed, skipping event publishing");
        return;
      }

      publishUpdated(singletonList(oldRecord));
    };
  }

  @SuppressWarnings("unchecked")
  public Handler<Response> publishCreated() {
    return response -> {
      if (!isCreateSuccessResponse(response)) {
        log.warn("Record create failed, skipping event publishing");
        return;
      }

      publishCreated(singletonList((DomainType) response.getEntity()));
    };
  }

  public Handler<Response> publishCreatedOrUpdated(
    BatchOperationContext<DomainType> batchOperation) {

    return response -> {
      if (!isCreateSuccessResponse(response)) {
        log.warn("Records create/update failed, skipping event publishing");
        return;
      }

      log.info("Records created {}, records updated {}",
        batchOperation.getRecordsToBeCreated().size(),
        batchOperation.getExistingRecords().size());

      publishCreated(batchOperation.getRecordsToBeCreated())
        .compose(notUsed -> publishUpdated(batchOperation.getExistingRecords()));
    };
  }

  public Handler<Response> publishRemoved(DomainType removedRecord) {
    return response -> {
      if (!isDeleteSuccessResponse(response)) {
        log.warn("Record removal failed, no event will be sent");
        return;
      }

      getInstanceId(removedRecord)
        .compose(instanceId -> domainEventService.publishRecordRemoved(instanceId,
          convertDomainToEvent(instanceId, removedRecord)));
    };
  }

  public Future<Void> publishAllRemoved() {
    return domainEventService.publishAllRecordsRemoved();
  }

  protected Future<Void> publishUpdated(Collection<DomainType> oldRecords) {
    if (oldRecords.isEmpty()) {
      log.info("No records were updated, skipping event sending");
      return succeededFuture();
    }

    log.info("[{}] records were updated, sending events for them", oldRecords.size());

    return repository.getById(oldRecords, this::getId)
      .compose(updatedItems -> convertDomainsToEvents(updatedItems.values(), oldRecords))
      .compose(domainEventService::publishRecordsUpdated);
  }

  private Future<Void> publishCreated(Collection<DomainType> records) {
    return convertDomainsToEvents(records)
      .compose(domainEventService::publishRecordsCreated);
  }

  protected abstract Future<List<Pair<String, DomainType>>> getInstanceIds(
    Collection<DomainType> domainTypes);

  protected abstract EventType convertDomainToEvent(String instanceId, DomainType domain);

  protected abstract String getId(DomainType record);

  private Future<List<Pair<String, EventType>>> convertDomainsToEvents(Collection<DomainType> domains) {
    return getInstanceIds(domains)
      .map(pairs -> pairs.stream()
        .map(pair -> pair(pair.getKey(), convertDomainToEvent(pair.getKey(), pair.getValue())))
        .collect(toList()));
  }

  private Future<List<Triple<String, EventType, EventType>>> convertDomainsToEvents(
    Collection<DomainType> newRecords, Collection<DomainType> oldRecords) {

    return getInstanceIds(oldRecords)
      .compose(oldRecordsInstanceIds -> getInstanceIds(newRecords)
        .map(newRecordsInstanceIds -> mapOldRecordsToNew(oldRecordsInstanceIds, newRecordsInstanceIds)));
  }

  protected List<Triple<String, EventType, EventType>> mapOldRecordsToNew(
    List<Pair<String, DomainType>> oldRecords, List<Pair<String, DomainType>> newRecords) {

    var idToOldRecordPairMap = oldRecords.stream()
      .collect(toMap(pair -> getId(pair.getValue()), pair -> pair));

    return newRecords.stream()
      .map(newRecordPair -> {
        var oldRecordPair = idToOldRecordPairMap.get(getId(newRecordPair.getValue()));
        return triple(newRecordPair.getKey(),
          convertDomainToEvent(oldRecordPair.getKey(), oldRecordPair.getValue()),
          convertDomainToEvent(newRecordPair.getKey(), newRecordPair.getValue()));
      }).collect(toList());
  }

  private Future<String> getInstanceId(DomainType domainType) {
    return getInstanceIds(List.of(domainType))
      .map(CollectionUtil::getFirst)
      .map(Pair::getKey);
  }
  static <L, R> Pair<L, R> pair(L left, R right) {
    return new ImmutablePair<>(left, right);
  }

  static <L, M, R> Triple<L, M, R> triple(L left, M middle, R right) {
    return new ImmutableTriple<>(left, middle, right);
  }
}
