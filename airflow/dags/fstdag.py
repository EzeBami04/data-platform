from airflow import DAG
from airflow.operators import BashOperator
from airflow.utils.dates import days_ago

with DAG(
    dag_id='dbt_transformations',
    schedule_interval='@daily',
    start_date=days_ago(1),
    catchup=False,
    tags=['dbt', 'transform'],
) as dag:
    install_deps = BashOperator(
        task_id='dbt_deps',
        bash_command='cd /opt/sql/qntplatform && dbt deps',
    )

    run_dbt = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/sql/qntplatform && dbt run --profiles-dir /opt/sql/qntplatform',
    )

    test_dbt = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/sql/qntplatform && dbt test --profiles-dir /opt/sql/qntplatform',
    )

    install_deps >> run_dbt >> test_dbt

