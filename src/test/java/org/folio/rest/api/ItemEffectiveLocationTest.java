package org.folio.rest.api;

import static org.folio.rest.support.http.InterfaceUrls.holdingsStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.instancesStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.itemsStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.loanTypesStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.locCampusStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.locInstitutionStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.locLibraryStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.locationsStorageUrl;
import static org.folio.rest.support.http.InterfaceUrls.materialTypesStorageUrl;
import static org.folio.util.StringUtil.urlEncode;
import static org.hamcrest.CoreMatchers.hasItems;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.not;
import static org.hamcrest.text.IsEmptyString.isEmptyString;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertThat;
import static org.junit.Assert.assertTrue;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import org.apache.commons.lang3.ObjectUtils;
import org.folio.rest.jaxrs.model.Item;
import org.folio.rest.jaxrs.model.Items;
import org.folio.rest.support.IndividualResource;
import org.folio.rest.support.Response;
import org.folio.rest.support.ResponseHandler;
import org.folio.rest.support.client.LoanTypesClient;
import org.folio.rest.support.client.MaterialTypesClient;
import org.folio.rest.support.http.InterfaceUrls;
import org.junit.After;
import org.junit.BeforeClass;
import org.junit.Test;
import org.junit.runner.RunWith;

import io.vertx.core.http.HttpClientResponse;
import io.vertx.core.json.JsonObject;
import junitparams.JUnitParamsRunner;
import junitparams.Parameters;

/**
 * Test cases to verify effectiveLocationId property calculation that implemented
 * as two triggers for holdings_record and item tables (see itemEffectiveLocation.sql)
 */
@RunWith(JUnitParamsRunner.class)
public class ItemEffectiveLocationTest extends TestBaseWithInventoryUtil {
  private static final String PERMANENT_LOCATION_ID_KEY = "permanentLocationId";
  private static final String TEMPORARY_LOCATION_ID_KEY = "temporaryLocationId";
  private static final String EFFECTIVE_LOCATION_ID_KEY = "effectiveLocationId";

  private static final String MAIN_LIBRARY_LOCATION = "Main Library (Item)";
  private static final String SECOND_FLOOR_LOCATION = "Second Floor (item)";
  private static final String ANNEX_LIBRARY_LOCATION = "Annex Library (item)";
  private static final String ONLINE_LOCATION = "Online (item)";
  private static final String THIRD_FLOOR_LOCATION = "Third Floor (item)";
  private static final String FOURTH_FLOOR_LOCATION = "Fourth Floor (item)";

  private static String journalMaterialTypeID;
  private static String canCirculateLoanTypeID;
  private static UUID instanceId;

  private static UUID mainLibraryLocationId = UUID.randomUUID();
  private static UUID annexLibraryLocationId = UUID.randomUUID();
  private static UUID onlineLocationId = UUID.randomUUID();
  private static UUID secondFloorLocationId = UUID.randomUUID();
  private static UUID thirdFloorLocationId = UUID.randomUUID();
  private static UUID fourthFloorLocationId = UUID.randomUUID();
  private static Map<UUID, String> locationIdToNameMap = buildLocationIdToNameMap();

  @BeforeClass
  public static void beforeAny() throws Exception {
    StorageTestSuite.deleteAll(itemsStorageUrl(""));
    StorageTestSuite.deleteAll(holdingsStorageUrl(""));
    StorageTestSuite.deleteAll(instancesStorageUrl(""));

    StorageTestSuite.deleteAll(materialTypesStorageUrl(""));
    StorageTestSuite.deleteAll(locationsStorageUrl(""));
    StorageTestSuite.deleteAll(locLibraryStorageUrl(""));
    StorageTestSuite.deleteAll(locCampusStorageUrl(""));
    StorageTestSuite.deleteAll(locInstitutionStorageUrl(""));
    StorageTestSuite.deleteAll(loanTypesStorageUrl(""));

    MaterialTypesClient materialTypesClient = new MaterialTypesClient(client, materialTypesStorageUrl(""));
    journalMaterialTypeID = materialTypesClient.create("journal");
    canCirculateLoanTypeID = new LoanTypesClient(client, loanTypesStorageUrl("")).create("Can Circulate");

    instanceId = instancesClient.create(instance(UUID.randomUUID())).getId();

    LocationsTest.createLocUnits(true);
    LocationsTest.createLocation(mainLibraryLocationId, MAIN_LIBRARY_LOCATION, "It/M");
    LocationsTest.createLocation(annexLibraryLocationId, ANNEX_LIBRARY_LOCATION, "It/A");
    LocationsTest.createLocation(onlineLocationId, ONLINE_LOCATION, "It/O");
    LocationsTest.createLocation(secondFloorLocationId, SECOND_FLOOR_LOCATION, "It/SF");
    LocationsTest.createLocation(thirdFloorLocationId, THIRD_FLOOR_LOCATION, "It/TF");
    LocationsTest.createLocation(fourthFloorLocationId, FOURTH_FLOOR_LOCATION, "It/FF");
  }

  @After
  public void checkIdsAfterEach() {
    StorageTestSuite.checkForMismatchedIDs("item");
    StorageTestSuite.checkForMismatchedIDs("holdings_record");
  }

  public void canCalculateEffectiveLocationOnHoldingUpdate() throws Exception {
    UUID holdingsRecordId = createInstanceAndHolding(mainLibraryLocationId);

    final Item[] itemsToCreate = {
      buildItem(holdingsRecordId, null, null),
      buildItem(holdingsRecordId, null, null),
      buildItem(holdingsRecordId, null, null)
    };

    for (Item item : itemsToCreate) {
      IndividualResource createdItem = createItem(item);
      assertTrue(createdItem.getJson().containsKey("effectiveLocationId"));
    }

    JsonObject holding = holdingsClient.getById(holdingsRecordId).getJson();
    holding.put("temporaryLocationId", secondFloorLocationId.toString());
    holdingsClient.replace(holdingsRecordId, holding);

    for (Item item : itemsToCreate) {
      Item fetchedItem = getItem(item.getId());
      assertEquals(fetchedItem.getEffectiveLocationId(), secondFloorLocationId.toString());
    }
  }

  @Test
  public void canCalculateEffectiveLocationOnHoldingRemoveTempLocationShouldBeHoldingPermLocation() throws Exception {
    UUID holdingsRecordId = createInstanceAndHolding(mainLibraryLocationId, annexLibraryLocationId);

    final Item[] itemsToCreate = {
      buildItem(holdingsRecordId, null, null),
      buildItem(holdingsRecordId, null, null),
      buildItem(holdingsRecordId, null, null)
    };

    for (Item item : itemsToCreate) {
      IndividualResource createdItem = createItem(item);
      assertTrue(createdItem.getJson().containsKey("effectiveLocationId"));
    }

    JsonObject holding = holdingsClient.getById(holdingsRecordId).getJson();
    holding.remove("temporaryLocationId");
    holdingsClient.replace(holdingsRecordId, holding);

    for (Item item : itemsToCreate) {
      Item fetchedItem = getItem(item.getId());
      assertEquals(fetchedItem.toString(), fetchedItem.getEffectiveLocationId(), mainLibraryLocationId.toString());
    }
  }

  @Test
  public void canCalculateEffectiveLocationOnHoldingUpdateWhenSomeItemsHasLocation() throws Exception {
    UUID holdingsRecordId = createInstanceAndHolding(mainLibraryLocationId);

    Item itemWithPermLocation = buildItem(holdingsRecordId, onlineLocationId, null);
    Item itemNoLocation = buildItem(holdingsRecordId, null, null);
    Item itemWithTempLocation = buildItem(holdingsRecordId, null, annexLibraryLocationId);

    createItem(itemWithPermLocation);
    createItem(itemNoLocation);
    createItem(itemWithTempLocation);

    JsonObject holding = holdingsClient.getById(holdingsRecordId).getJson();
    holding.put("temporaryLocationId", secondFloorLocationId.toString());
    holdingsClient.replace(holdingsRecordId, holding);

    // fetch items
    Item itemWithPermLocationFetched = getItem(itemWithPermLocation.getId());
    Item itemNoLocationFetched = getItem(itemNoLocation.getId());
    Item itemWithTempLocationFetched = getItem(itemWithTempLocation.getId());

    // Assert that itemWithPermLocationFetched was not updated
    assertEquals(itemWithPermLocationFetched.getEffectiveLocationId(), onlineLocationId.toString());

    // Assert that itemNoLocationFetched was updated
    assertEquals(itemNoLocationFetched.getEffectiveLocationId(), secondFloorLocationId.toString());

    // Assert that itemWithPermLocationFetched was not updated
    assertEquals(itemWithTempLocationFetched.getEffectiveLocationId(), annexLibraryLocationId.toString());
  }

  @Test
  public void removesPropertyWhenEffectiveLocationIsNull() throws Exception {
    UUID holdingsRecordId = createHolding(instanceId, null, null);

    Item item = buildItem(holdingsRecordId, null, null);
    JsonObject createdItem = createItem(item).getJson();

    assertFalse(createdItem.containsKey("effectiveLocationId"));
  }

  @Test
  @Parameters(method = "parameters")
  public void canCalculateEffectiveLocationOnItemUpdate(
      PermTemp holdingLoc, PermTemp itemStartLoc, PermTemp itemEndLoc) throws Exception {

    UUID holdingsRecordId = createHolding(instanceId, holdingLoc.perm, holdingLoc.temp);

    Item item = buildItem(holdingsRecordId, itemStartLoc.perm, itemStartLoc.temp);
    UUID itemId = UUID.fromString(item.getId());
    IndividualResource itemResource = createItem(item);
    JsonObject item2 = itemResource.getJson();
    assertEffectiveLocation(item2, holdingLoc, itemStartLoc);

    setPermanentTemporaryLocation(item2, itemEndLoc);
    itemsClient.replace(itemId, item2);
    JsonObject item3 = itemsClient.getById(itemId).getJson();
    assertEffectiveLocation(item3, holdingLoc, itemEndLoc);
  }

  @Test
  @Parameters(method = "parameters")   // res-use swapping item and holding
  public void canCalculateEffectiveLocationOnIHoldingUpdate(
      PermTemp itemLoc, PermTemp holdingStartLoc, PermTemp holdingEndLoc) throws Exception {

    UUID holdingsRecordId = createHolding(instanceId, holdingStartLoc.perm, holdingStartLoc.temp);

    Item item = buildItem(holdingsRecordId, itemLoc.perm, itemLoc.temp);
    UUID itemId = UUID.fromString(item.getId());
    JsonObject item2 = createItem(item).getJson();
    assertEffectiveLocation(item2, holdingStartLoc, itemLoc);

    JsonObject holding2 = holdingsClient.getById(holdingsRecordId).getJson();
    setPermanentTemporaryLocation(holding2, holdingEndLoc);
    holdingsClient.replace(holdingsRecordId, holding2);
    JsonObject item3 = itemsClient.getById(itemId).getJson();
    assertEffectiveLocation(item3, holdingEndLoc, itemLoc);
  }

  @Test
  public void canSearchItemByEffectiveLocation() throws Exception {
    StorageTestSuite.deleteAll(itemsStorageUrl(""));
    StorageTestSuite.deleteAll(holdingsStorageUrl(""));

    UUID holdingsWithPermLocation = createInstanceAndHolding(mainLibraryLocationId);
    UUID holdingsWithTempLocation = createInstanceAndHolding(mainLibraryLocationId, annexLibraryLocationId);

    Item itemWithHoldingPermLocation = buildItem(holdingsWithPermLocation, null, null);
    Item itemWithHoldingTempLocation = buildItem(holdingsWithTempLocation, null, null);
    Item itemWithTempLocation = buildItem(holdingsWithPermLocation, onlineLocationId, null);
    Item itemWithPermLocation = buildItem(holdingsWithTempLocation, null, secondFloorLocationId);
    Item itemWithAllLocation = buildItem(holdingsWithTempLocation, secondFloorLocationId, onlineLocationId);

    Item[] itemsToCreate = {itemWithHoldingPermLocation, itemWithHoldingTempLocation,
      itemWithTempLocation, itemWithPermLocation, itemWithAllLocation};

    for (Item item : itemsToCreate) {
      IndividualResource createdItem = createItem(item);
      assertTrue(createdItem.getJson().containsKey("effectiveLocationId"));
    }

    Items mainLibraryItems = findItems("effectiveLocationId=" + mainLibraryLocationId);
    Items annexLibraryItems = findItems("effectiveLocationId=" + annexLibraryLocationId);
    Items onlineLibraryItems = findItems("effectiveLocationId=" + onlineLocationId);
    Items secondFloorLibraryItems = findItems("effectiveLocationId=" + secondFloorLocationId);

    assertEquals(1, mainLibraryItems.getTotalRecords().intValue());
    assertThat(mainLibraryItems.getItems().get(0).getId(), is(itemWithHoldingPermLocation.getId()));

    assertEquals(1, annexLibraryItems.getTotalRecords().intValue());
    assertThat(annexLibraryItems.getItems().get(0).getId(), is(itemWithHoldingTempLocation.getId()));

    assertEquals(2, onlineLibraryItems.getTotalRecords().intValue());

    assertThat(onlineLibraryItems.getItems()
        .stream()
        .map(Item::getId)
        .collect(Collectors.toList()),
      hasItems(itemWithTempLocation.getId(), itemWithAllLocation.getId()));

    assertEquals(1, secondFloorLibraryItems.getTotalRecords().intValue());
    assertThat(secondFloorLibraryItems.getItems().get(0).getId(), is(itemWithPermLocation.getId()));
  }

  @Test
  public void responseContainsAllRequiredHeaders() throws Exception {
    UUID holdingsRecordId = createInstanceAndHolding(mainLibraryLocationId, annexLibraryLocationId);

    CompletableFuture<HttpClientResponse> createCompleted = new CompletableFuture<>();
    Item item = buildItem(holdingsRecordId, null, null);

    client
      .post(InterfaceUrls.itemsStorageUrl(""), item,
        StorageTestSuite.TENANT_ID, createCompleted::complete);

    HttpClientResponse response = createCompleted.get(5, TimeUnit.SECONDS);

    assertThat(response.statusCode(), is(201));
    assertThat(response.getHeader("location"), not(isEmptyString()));
  }

  @Test
  public void canCalculateEffectiveLocationWhenItemAssociatedToAnotherHolding() throws Exception {
    UUID initialHoldingsRecordId = createInstanceAndHolding(mainLibraryLocationId, annexLibraryLocationId);
    UUID updatedHoldingRecordId = createInstanceAndHolding(onlineLocationId, secondFloorLocationId);

    Item item = buildItem(initialHoldingsRecordId, null, null);
    createItem(item);

    Item itemFetched = getItem(item.getId());
    assertEquals(itemFetched.getEffectiveLocationId(), annexLibraryLocationId.toString());

    itemsClient.replace(UUID.fromString(itemFetched.getId()),
      JsonObject.mapFrom(itemFetched).copy()
        .put("holdingsRecordId", updatedHoldingRecordId.toString())
    );

    assertEquals(getItem(item.getId()).getEffectiveLocationId(), secondFloorLocationId.toString());
  }

  @Test
  public void canCalculateEffectiveLocationWhenItemHasPermLocationAndAssociatedToAnotherHolding() throws Exception {
    UUID initialHoldingsRecordId = createInstanceAndHolding(mainLibraryLocationId, annexLibraryLocationId);
    UUID updatedHoldingRecordId = createInstanceAndHolding(secondFloorLocationId);

    Item item = buildItem(initialHoldingsRecordId, onlineLocationId, null);
    createItem(item);

    Item itemFetched = getItem(item.getId());
    assertEquals(itemFetched.getEffectiveLocationId(), onlineLocationId.toString());

    itemsClient.replace(UUID.fromString(itemFetched.getId()),
      JsonObject.mapFrom(itemFetched).copy()
        .put("holdingsRecordId", updatedHoldingRecordId.toString())
    );

    assertEquals(getItem(item.getId()).getEffectiveLocationId(), onlineLocationId.toString());
  }

  private Item buildItem(UUID holdingsRecordId,
                         UUID permLocation,
                         UUID tempLocation) {
    JsonObject itemToCreate = new JsonObject();

    itemToCreate.put("id", UUID.randomUUID().toString());
    itemToCreate.put("holdingsRecordId", holdingsRecordId.toString());
    itemToCreate.put("barcode", Long.toString(new Random().nextLong()));
    itemToCreate.put("status", new JsonObject().put("name", "Available"));
    itemToCreate.put("materialTypeId", journalMaterialTypeID);
    itemToCreate.put("permanentLoanTypeId", canCirculateLoanTypeID);
    if (tempLocation != null) {
      itemToCreate.put(TEMPORARY_LOCATION_ID_KEY, tempLocation.toString());
    }
    if (permLocation != null) {
      itemToCreate.put(PERMANENT_LOCATION_ID_KEY, permLocation.toString());
    }

    return itemToCreate.mapTo(Item.class);
  }

  private Item getItem(String id) throws Exception {
    return itemsClient.getById(UUID.fromString(id)).getJson().mapTo(Item.class);
  }

  private Items findItems(String searchQuery) throws Exception {
    CompletableFuture<Response> searchCompleted = new CompletableFuture<>();

    client.get(itemsStorageUrl("?query=") + urlEncode(searchQuery),
      StorageTestSuite.TENANT_ID, ResponseHandler.json(searchCompleted));

    return searchCompleted.get(5, TimeUnit.SECONDS).getJson()
      .mapTo(Items.class);
  }

  private IndividualResource createItem(Item item) throws Exception {
    return itemsClient.create(JsonObject.mapFrom(item));
  }

  /** Store a permanent location UUID and a temporary location UUID. */
  private static class PermTemp {
    /** permanent location UUID */
    UUID perm;
    /** temporary location UUID */
    UUID temp;
    /**
     * @param perm permanent location UUID
     * @param temp temporary location UUID
     */
    PermTemp(UUID perm, UUID temp) {
      this.perm = perm;
      this.temp = temp;
    }
    /**
     * The first character of the perm UUID and of the temp UUID; use _ for null.
     * IDE's JUnit views show this String as the unit test parameter.
     */
    @Override
    public String toString() {
      return locationIdToNameMap.get(perm) + ", " + locationIdToNameMap.get(temp);
    }
  }

@SuppressWarnings("unused")  // is actually used by @Parameters(method = "parameters")
private List<PermTemp[]> parameters() {
    List<PermTemp[]> list = new ArrayList<>();
    PermTemp[] holdingLocationsList = {
      new PermTemp(null, null),
      new PermTemp(null, mainLibraryLocationId),
      new PermTemp(mainLibraryLocationId, null),
      new PermTemp(mainLibraryLocationId, annexLibraryLocationId),
    };
    PermTemp[] itemStartLocationsList = {
      new PermTemp(null, null),
      new PermTemp(null, onlineLocationId),
      new PermTemp(onlineLocationId, null),
      new PermTemp(onlineLocationId, secondFloorLocationId),
    };
    PermTemp[] itemEndLocationsList = {
      new PermTemp(null, null),
      new PermTemp(null, onlineLocationId),
      new PermTemp(onlineLocationId, null),
      new PermTemp(onlineLocationId, secondFloorLocationId),
      new PermTemp(null, thirdFloorLocationId),
      new PermTemp(thirdFloorLocationId, null),
      new PermTemp(thirdFloorLocationId, fourthFloorLocationId),
    };

    for (PermTemp holdingLocations : holdingLocationsList) {
      for (PermTemp itemStartLocations : itemStartLocationsList) {
        for (PermTemp itemEndLocations : itemEndLocationsList) {
          list.add(new PermTemp[]{holdingLocations, itemStartLocations, itemEndLocations});
        }
      }
    }
    return list;
  }

  private void setPermanentTemporaryLocation(JsonObject json, PermTemp locations) {
    if (locations.perm == null) {
      json.remove(PERMANENT_LOCATION_ID_KEY);
    } else {
      json.put(PERMANENT_LOCATION_ID_KEY, locations.perm.toString());
    }
    if (locations.temp == null) {
      json.remove(TEMPORARY_LOCATION_ID_KEY);
    } else {
      json.put(TEMPORARY_LOCATION_ID_KEY, locations.temp.toString());
    }
  }

  private void assertEffectiveLocation(
      JsonObject item, PermTemp holdingLocations, PermTemp itemLocations) {

    UUID expectedEffectiveLocation = ObjectUtils
        .firstNonNull(itemLocations.temp, itemLocations.perm, holdingLocations.temp, holdingLocations.perm);
    if (expectedEffectiveLocation == null) {
      // { "effectiveLocationId": null } is not allowed, the complete property must have been removed
      assertThat(item.containsKey(EFFECTIVE_LOCATION_ID_KEY), is(false));
      return;
    }
    assertThat(item.getString(EFFECTIVE_LOCATION_ID_KEY), is(expectedEffectiveLocation.toString()));
  }

  private static Map<UUID, String> buildLocationIdToNameMap() {
    HashMap<UUID, String> idToNameMap = new HashMap<>();

    idToNameMap.put(mainLibraryLocationId, MAIN_LIBRARY_LOCATION);
    idToNameMap.put(annexLibraryLocationId, ANNEX_LIBRARY_LOCATION);
    idToNameMap.put(onlineLocationId, ONLINE_LOCATION);
    idToNameMap.put(secondFloorLocationId, SECOND_FLOOR_LOCATION);
    idToNameMap.put(thirdFloorLocationId, THIRD_FLOOR_LOCATION);
    idToNameMap.put(fourthFloorLocationId, FOURTH_FLOOR_LOCATION);

    return idToNameMap;
  }
}
