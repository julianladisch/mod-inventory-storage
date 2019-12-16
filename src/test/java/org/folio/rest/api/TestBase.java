package org.folio.rest.api;

import static java.util.concurrent.TimeUnit.SECONDS;
import static org.folio.rest.api.StorageTestSuite.TENANT_ID;
import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertThat;

import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;

import org.folio.rest.persist.PostgresClient;
import org.folio.rest.support.HttpClient;
import org.folio.rest.support.Response;
import org.folio.rest.support.ResponseHandler;
import org.folio.rest.support.http.ResourceClient;
import org.junit.AfterClass;
import org.junit.BeforeClass;

import io.vertx.core.Vertx;

/**
 * When not run from StorageTestSuite then this class invokes StorageTestSuite.before() and
 * StorageTestSuite.after() to allow to run a single test class, for example from within an
 * IDE during development.
 */
public abstract class TestBase {
  private static boolean invokeStorageTestSuiteAfter = false;
  static HttpClient client;
  static ResourceClient instancesClient;
  static ResourceClient holdingsClient;
  static ResourceClient itemsClient;
  static ResourceClient locationsClient;

  @BeforeClass
  public static void testBaseBeforeClass() throws Exception {
    Vertx vertx = StorageTestSuite.getVertx();
    if (vertx == null) {
      invokeStorageTestSuiteAfter = true;
      StorageTestSuite.before();
      vertx = StorageTestSuite.getVertx();
    }

    client = new HttpClient(vertx);
    instancesClient = ResourceClient.forInstances(client);
    holdingsClient = ResourceClient.forHoldings(client);
    itemsClient = ResourceClient.forItems(client);
    locationsClient = ResourceClient.forLocations(client);
  }

  @AfterClass
  public static void testBaseAfterClass()
    throws InterruptedException,
    ExecutionException,
    TimeoutException,
    MalformedURLException {

    if (invokeStorageTestSuiteAfter) {
      StorageTestSuite.after();
    }
  }

  /**
   * Assert that a GET at the url returns 404 status code (= not found).
   * @param url  endpoint where to execute a GET request
   */
  void assertGetNotFound(URL url) {
    CompletableFuture<Response> getCompleted = new CompletableFuture<>();

    client.get(url, TENANT_ID, ResponseHandler.text(getCompleted));
    Response response;
    try {
      response = getCompleted.get(5, SECONDS);
      assertThat(response.getStatusCode(), is(HttpURLConnection.HTTP_NOT_FOUND));
    } catch (InterruptedException | ExecutionException | TimeoutException e) {
      throw new RuntimeException(e);
    }
  }

  /**
   * Executes multiply SQL statements separated by a line separator (either CRLF|CR|LF).
   *
   * @param allStatements - Statements to execute (separated by a line separator).
   * @throws InterruptedException
   * @throws ExecutionException
   * @throws TimeoutException
   */
  void executeMultipleSqlStatements(String allStatements)
    throws InterruptedException, ExecutionException, TimeoutException {

    final CompletableFuture<Void> result = new CompletableFuture<>();
    final Vertx vertx = StorageTestSuite.getVertx();

    PostgresClient.getInstance(vertx).runSQLFile(allStatements, true, handler -> {
      if (handler.failed()) {
        result.completeExceptionally(handler.cause());
      } else if (!handler.result().isEmpty()) {
        result.completeExceptionally(new RuntimeException("Failing SQL: " + handler.result().toString()));
      } else {
        result.complete(null);
      }
    });

    result.get(5, SECONDS);
  }

  void executeSql(String sql)
    throws InterruptedException, ExecutionException, TimeoutException {

    final CompletableFuture<Void> result = new CompletableFuture<>();
    final Vertx vertx = StorageTestSuite.getVertx();

    PostgresClient.getInstance(vertx).execute(sql, updateResult -> {
      if (updateResult.failed()) {
        result.completeExceptionally(updateResult.cause());
      } else {
        result.complete(null);
      }
    });

    result.get(5, SECONDS);
  }
}
