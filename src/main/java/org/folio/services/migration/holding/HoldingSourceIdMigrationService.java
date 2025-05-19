package org.folio.services.migration.holding;

import static org.folio.services.migration.MigrationName.HOLDING_SOURCE_ID_MIGRATION;

import io.vertx.core.Context;
import io.vertx.core.Future;
import io.vertx.sqlclient.Row;
import io.vertx.sqlclient.RowStream;
import java.util.List;
import java.util.Map;
import org.folio.rest.persist.PgUtil;
import org.folio.rest.persist.PostgresClient;
import org.folio.rest.persist.PostgresClientFuturized;
import org.folio.rest.persist.SQLConnection;
import org.folio.services.migration.BaseMigrationService;
import org.folio.util.ResourceUtil;

public class HoldingSourceIdMigrationService extends BaseMigrationService {
  private static final String SQL = ResourceUtil.asString("templates/db_scripts/populateHoldingsSourceId.sql");

  private final PostgresClient postgresClient;

  public HoldingSourceIdMigrationService(Context context, Map<String, String> okapiHeaders) {
    this(PgUtil.postgresClient(context, okapiHeaders));
  }

  public HoldingSourceIdMigrationService(PostgresClient postgresClient) {
    super("28.0.13", new PostgresClientFuturized(postgresClient));
    this.postgresClient = postgresClient;
  }

  @Override
  public Future<Void> runMigration() {
    // runs as DB_USER user (~ superuser) with read permission for …_mod_source_record_storage.records_lb
    return postgresClient.runSqlFile(SQL);
  }

  @Override
  protected Future<RowStream<Row>> openStream(SQLConnection connection) {
    return Future.failedFuture("not implemented");
  }

  @Override
  protected Future<Integer> updateBatch(List<Row> batch, SQLConnection connection) {
    return Future.failedFuture("not implemented");
  }

  @Override
  public String getMigrationName() {
    return HOLDING_SOURCE_ID_MIGRATION.getValue();
  }
}
