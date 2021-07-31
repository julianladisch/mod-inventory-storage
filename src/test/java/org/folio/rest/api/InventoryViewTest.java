package org.folio.rest.api;

import static java.util.UUID.randomUUID;
import static java.util.stream.Collectors.toList;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.Assert.assertTrue;

import io.vertx.core.json.JsonObject;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;
import org.folio.rest.jaxrs.model.HoldingsItem;
import org.folio.rest.jaxrs.model.HoldingsRecords2;
import org.folio.rest.jaxrs.model.InventoryViewInstance;
import org.folio.rest.support.IndividualResource;
import org.hamcrest.Matcher;
import org.hamcrest.Matchers;
import org.junit.Test;

public class InventoryViewTest extends TestBaseWithInventoryUtil {
  @Test
  public void shouldReturnInstanceWithRecords() {
    var instanceOne = instancesClient.create(instance(randomUUID()));
    var holdingsForOne = List.of(
      createHolding(instanceOne.getId(), mainLibraryLocationId, null),
      createHolding(instanceOne.getId(), secondFloorLocationId, null)
    );
    var itemsForOne = List.of(
      createItem(nod(holdingsForOne.get(0))).getString("id"),
      createItem(nod(holdingsForOne.get(1))).getString("id")
    );

    var instanceTwo = instancesClient.create(instance(randomUUID()));
    var holdingsForTwo = List.of(
      createHolding(instanceTwo.getId(), mainLibraryLocationId, null),
      createHolding(instanceTwo.getId(), secondFloorLocationId, null),
      createHolding(instanceTwo.getId(), fourthFloorLocationId, null));
    var itemsForTwo = List.of(
      createItem(nod(holdingsForTwo.get(0))).getString("id"),
      createItem(nod(holdingsForTwo.get(0))).getString("id"),
      createItem(nod(holdingsForTwo.get(1))).getString("id"),
      createItem(nod(holdingsForTwo.get(2))).getString("id"));

    var instances = inventoryViewClient.getMany("id==(%s or %s)",
      instanceTwo.getId(), instanceOne.getId());

    assertThat(instances.size(), is(2));

    var firstInstance = getInstanceById(instances, instanceOne.getId());
    var secondInstance = getInstanceById(instances, instanceTwo.getId());

    assertThat(getHoldingIds(firstInstance), matchesInAnyOrder(holdingsForOne));
    assertThat(getItemIds(firstInstance), matchesInAnyOrder(itemsForOne));

    assertThat(getHoldingIds(secondInstance), matchesInAnyOrder(holdingsForTwo));
    assertThat(getItemIds(secondInstance), matchesInAnyOrder(itemsForTwo));
  }

  @Test
  public void shouldReturnInstanceEvenIfNoItems() {
    var instanceOne = instancesClient.create(instance(randomUUID()));
    var holdingForOne = createHolding(instanceOne.getId(), mainLibraryLocationId, null);

    var instanceTwo = instancesClient.create(instance(randomUUID()));
    var holdingsForTwo = List.of(
      createHolding(instanceTwo.getId(), mainLibraryLocationId, null),
      createHolding(instanceTwo.getId(), secondFloorLocationId, null),
      createHolding(instanceTwo.getId(), fourthFloorLocationId, null));

    var instances = inventoryViewClient.getMany("id==(%s or %s)",
      instanceTwo.getId(), instanceOne.getId());

    assertThat(instances.size(), is(2));

    var firstInstance = getInstanceById(instances, instanceOne.getId());
    var secondInstance = getInstanceById(instances, instanceTwo.getId());

    assertThat(firstInstance.getHoldingsRecords().get(0).getId(), is(holdingForOne.toString()));
    assertThat(getHoldingIds(secondInstance), matchesInAnyOrder(holdingsForTwo));

    isNonNullEmpty(firstInstance.getItems());
    isNonNullEmpty(secondInstance.getItems());
  }

  @Test
  public void shouldReturnInstanceEvenIfNoHoldings() {
    var instanceOne = instancesClient.create(instance(randomUUID()));
    var instanceTwo = instancesClient.create(instance(randomUUID()));

    var instances = inventoryViewClient.getMany("id==(%s or %s)",
      instanceTwo.getId(), instanceOne.getId());

    assertThat(instances.size(), is(2));

    var returnedInstances = instances.stream()
      .map(resource -> resource.getJson().mapTo(InventoryViewInstance.class))
      .collect(Collectors.toList());

    for (InventoryViewInstance returnedInstance : returnedInstances) {
      isNonNullEmpty(returnedInstance.getHoldingsRecords());
      isNonNullEmpty(returnedInstance.getItems());

      assertTrue(returnedInstance.getInstanceId().equals(instanceOne.getId().toString())
        || returnedInstance.getInstanceId().equals(instanceTwo.getId().toString()));
    }
  }

  /**
   * nod without barcode to allow multiple items
   */
  static JsonObject nod(UUID holdingsRecordId) {
    return ItemStorageTest.removeBarcode(ItemStorageTest.nod(holdingsRecordId));
  }

  private List<UUID> getHoldingIds(InventoryViewInstance instance) {
    return instance.getHoldingsRecords().stream()
      .map(HoldingsRecords2::getId)
      .map(UUID::fromString)
      .collect(toList());
  }

  private List<String> getItemIds(InventoryViewInstance instance) {
    return instance.getItems().stream()
      .map(HoldingsItem::getId)
      .collect(toList());
  }

  private <T> Matcher<Iterable<? extends T>> matchesInAnyOrder(List<T> records) {
    return containsInAnyOrder(records.stream()
    .map(Matchers::is)
    .collect(Collectors.toList()));
  }

  private void isNonNullEmpty(List<?> aList) {
    assertThat(aList, notNullValue());
    assertThat(aList.size(), is(0));
  }

  private InventoryViewInstance getInstanceById(List<IndividualResource> instances, UUID id) {
    return instances.stream()
      .map(r -> r.getJson().mapTo(InventoryViewInstance.class))
      .filter(r -> r.getInstanceId().equals(id.toString()))
      .findFirst()
      .orElseThrow(() -> new AssertionError("No instance"));
  }
}
