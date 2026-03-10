#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Rzavala DBF Uploader
Uploads both production orders and inventory codes to WMS API

Company: Rzavala
Token: 74bf5e0a6ae8813dfe80593ed84a7a9c
Warehouse ID: f7a1f77a-0802-49e3-871e-55bc917094f9

Production Orders: opro.dbf + oprod.dbf
Inventory Codes: remd.dbf
"""

import requests
import time
import logging
from datetime import datetime
from dbfread import DBF
import os
import json
import sys
from typing import Dict, List, Optional, Any

# Configure logging
log_filename = 'rzavala_dbf_uploader.log'
log_filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), log_filename) if os.path.dirname(os.path.abspath(__file__)) else log_filename
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filepath, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('RzavalaDBFUploader')

# Company configuration
COMPANY_NAME = "Rzavala"
COMPANY_TOKEN = "74bf5e0a6ae8813dfe80593ed84a7a9c"
WAREHOUSE_ID = "f7a1f77a-0802-49e3-871e-55bc917094f9"

# API configuration
API_BASE_URL = "https://wmsys.fly.dev"
API_OPRO_ENDPOINT = "/api/production_orders/batch"
API_INVENTORY_ENDPOINT = "/api/inventory_codes/batch"
API_LAST_OPRO_ENDPOINT = "/api/production_orders/last_no_opro"
API_TIMEOUT = 90
MAX_RETRIES = 3
BATCH_SIZE = 25

# Configuration for file paths
if getattr(sys, 'frozen', False):
    application_path = sys._MEIPASS
    OPRO_DBF_PATH = r"C:\ALPHAERP\Empresas\RZAVALA\opro.dbf"
    OPROD_DBF_PATH = r"C:\ALPHAERP\Empresas\RZAVALA\oprod.dbf"
    REMD_DBF_PATH = r"C:\ALPHAERP\Empresas\RZAVALA\remd.dbf"
else:
    application_path = os.path.dirname(os.path.abspath(__file__))
    OPRO_DBF_PATH = os.path.join(application_path, 'opro.dbf')
    OPROD_DBF_PATH = os.path.join(application_path, 'oprod.dbf')
    REMD_DBF_PATH = os.path.join(application_path, 'remd.dbf')

# State files
OPRO_STATE_FILE = os.path.join(application_path, "rzavala_opro_state.json")
INVENTORY_STATE_FILE = os.path.join(application_path, "rzavala_inventory_state.json")
LAST_MODIFIED_FILE = os.path.join(application_path, "rzavala_modified_state.json")


class RzavalaDBFUploader:
    def __init__(self):
        self.session = requests.Session()
        self.opro_state = self.load_opro_state()
        self.inventory_state = self.load_inventory_state()
        self.last_modified_state = self.load_last_modified_state()
        self.first_run = not os.path.exists(OPRO_STATE_FILE) and not os.path.exists(INVENTORY_STATE_FILE)
        self.sync_last_opro_from_api()

    def get_last_opro_from_api(self) -> int:
        """Get the last NO_OPRO from WMSys API"""
        try:
            logger.info("Fetching last NO_OPRO from API...")
            response = self.session.get(
                API_BASE_URL + API_LAST_OPRO_ENDPOINT,
                headers={'X-Company-Token': COMPANY_TOKEN},
                timeout=30
            )
            if response.status_code == 200:
                data = response.json()
                last_opro = data.get('last_no_opro', 0)
                logger.info(f"API returned last NO_OPRO: {last_opro}")
                return int(last_opro) if last_opro else 0
            else:
                logger.warning(f"API returned status {response.status_code}")
        except Exception as e:
            logger.warning(f"Could not fetch last NO_OPRO from API: {e}")
        return 0

    def sync_last_opro_from_api(self):
        """Sync the last processed NO_OPRO from API"""
        api_last_opro = self.get_last_opro_from_api()
        local_last_opro = self.opro_state.get('last_processed_opro', 0)

        if api_last_opro > local_last_opro:
            logger.info(f"Syncing from API: {local_last_opro} -> {api_last_opro}")
            self.opro_state['last_processed_opro'] = api_last_opro
            self.save_opro_state()
        elif local_last_opro > api_last_opro:
            logger.info(f"Local state is ahead: {local_last_opro} > API: {api_last_opro}")

    def load_opro_state(self) -> Dict:
        """Load the last processed state for production orders"""
        try:
            if os.path.exists(OPRO_STATE_FILE):
                with open(OPRO_STATE_FILE, 'r', encoding='utf-8') as f:
                    state = json.load(f)
                    if 'last_processed_opro' not in state:
                        state['last_processed_opro'] = 0
                    return state
        except Exception as e:
            logger.warning(f"Could not load OPRO state file: {e}")
        return {'last_processed_opro': 0}

    def save_opro_state(self) -> bool:
        """Save the current state for production orders"""
        try:
            with open(OPRO_STATE_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.opro_state, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            logger.error(f"Error saving OPRO state: {e}")
            return False

    def load_inventory_state(self) -> Dict:
        """Load the last processed state for inventory codes"""
        try:
            if os.path.exists(INVENTORY_STATE_FILE):
                with open(INVENTORY_STATE_FILE, 'r', encoding='utf-8') as f:
                    state = json.load(f)
                    # Support both NO_ORDP and NO_REM for backwards compatibility
                    if 'last_processed_no_ordp' not in state:
                        state['last_processed_no_ordp'] = state.get('last_processed_no_rem', 0)
                    return state
        except Exception as e:
            logger.warning(f"Could not load inventory state file: {e}")
        return {'last_processed_no_ordp': 0}

    def save_inventory_state(self) -> bool:
        """Save the current state for inventory codes"""
        try:
            with open(INVENTORY_STATE_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.inventory_state, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            logger.error(f"Error saving inventory state: {e}")
            return False

    def load_last_modified_state(self) -> Dict:
        """Load the last modified timestamps from file"""
        try:
            if os.path.exists(LAST_MODIFIED_FILE):
                with open(LAST_MODIFIED_FILE, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Could not load last modified state file: {e}")
        return {}

    def save_last_modified_state(self) -> bool:
        """Save the current last modified timestamps to file"""
        try:
            with open(LAST_MODIFIED_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.last_modified_state, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            logger.error(f"Error saving last modified state: {e}")
            return False

    def get_file_last_modified(self, filepath: str) -> float:
        """Get the last modified timestamp of a file"""
        try:
            return os.path.getmtime(filepath)
        except Exception as e:
            logger.error(f"Error getting last modified time for {filepath}: {e}")
            return 0

    def has_file_changed(self, filepath: str) -> bool:
        """Check if a file has been modified since last check"""
        current_modified = self.get_file_last_modified(filepath)
        last_modified = self.last_modified_state.get(filepath, 0)

        if current_modified > last_modified:
            self.last_modified_state[filepath] = current_modified
            return True
        return False

    def clean_value(self, value: Any) -> str:
        """Clean and convert value to appropriate type"""
        if value is None or str(value).lower() in ['nan', 'none', '']:
            return ''
        if hasattr(value, 'strftime'):
            return value.isoformat()
        return str(value).strip()

    # ============================================================================
    # PRODUCTION ORDERS METHODS
    # ============================================================================

    def extract_quantity(self, record: Dict) -> int:
        """Extract meaningful quantity from various fields"""
        try:
            ren_opro = self.clean_value(record.get('REN_OPRO', '0'))
            carga_opro = self.clean_value(record.get('CARGA_OPRO', '0'))
            can_op = self.clean_value(record.get('CAN_OP', '0'))

            for value in [ren_opro, carga_opro, can_op]:
                if value and value.lower() not in ['nan', 'none', '', '0']:
                    try:
                        qty = float(value)
                        if qty > 0:
                            return max(1, int(qty))
                    except:
                        continue

            return 1000
        except:
            return 1000

    def extract_year(self, record: Dict) -> str:
        """Extract year from date field"""
        try:
            fec_opro = self.clean_value(record.get('FEC_OPRO', ''))

            if fec_opro:
                if '-' in fec_opro:
                    return fec_opro.split('-')[0]
                elif '/' in fec_opro:
                    parts = fec_opro.split('/')
                    if len(parts) == 3:
                        return parts[2] if len(parts[2]) == 4 else ''
                elif len(fec_opro) >= 4:
                    if fec_opro[:4].isdigit():
                        return fec_opro[:4]

            return str(datetime.now().year)
        except:
            return str(datetime.now().year)

    def map_opro_record_to_api(self, record: Dict) -> Optional[Dict]:
        """Map Excel record to API format for production orders"""
        try:
            cleaned = {k: self.clean_value(v) for k, v in record.items()}
            year = self.extract_year(cleaned)
            quantity = self.extract_quantity(cleaned)
            product_key = cleaned.get('CVE_PROP', '')
            no_opro = cleaned.get('NO_OPRO', '')

            if not no_opro:
                logger.warning("Skipping record: NO_OPRO is empty")
                return None

            if not product_key:
                logger.warning(f"Record with NO_OPRO {no_opro} has empty CVE_PROP")

            mapped = {
                "product_key": product_key,
                "quantity_requested": quantity,
                "warehouse_id": WAREHOUSE_ID,
                "priority": "medium",
                "no_opro": no_opro,
                "notes": cleaned.get('OBSERVA', ''),
                "lote_referencia": cleaned.get('LOTE', ''),
                "carga_copr": cleaned.get('CARGA_OPRO', ''),
                "ren_orp": cleaned.get('REN_OPRO', ''),
                "ano": year,
                "stat_opro": cleaned.get('STAT_OPRO', '')
            }

            mapped = {k: v for k, v in mapped.items() if v not in [None, 0] or k == 'notes'}

            logger.debug(f"Mapped OPRO record - NO_OPRO: {mapped.get('no_opro')}, "
                        f"Product: {mapped.get('product_key')}, "
                        f"Quantity: {mapped.get('quantity_requested')}")

            return mapped

        except Exception as e:
            logger.error(f"Error mapping OPRO record: {e}")
            return None

    def merge_opro_oprod(self, opro_records: List[Dict], oprod_records: List[Dict]) -> List[Dict]:
        """Merge opro and oprod records by NO_OPRO"""
        oprod_by_opro = {}
        for record in oprod_records:
            no_opro = str(record.get('NO_OPRO', ''))
            if no_opro:
                if no_opro not in oprod_by_opro:
                    oprod_by_opro[no_opro] = []
                oprod_by_opro[no_opro].append(record)

        merged_records = []
        for opro_record in opro_records:
            no_opro = str(opro_record.get('NO_OPRO', ''))
            if no_opro in oprod_by_opro:
                for oprod_record in oprod_by_opro[no_opro]:
                    merged = {**opro_record, **oprod_record}
                    merged_records.append(merged)
            else:
                merged_records.append(opro_record)

        logger.info(f"Merged {len(opro_records)} opro records with {len(oprod_records)} oprod records -> {len(merged_records)} total")
        return merged_records

    def send_opro_batch_to_api(self, batch_data: List[Dict]) -> Dict:
        """Send a batch of production orders to the API endpoint"""
        for attempt in range(MAX_RETRIES):
            try:
                logger.info(f"Sending batch of {len(batch_data)} production orders to API")

                payload = {
                    "company_name": COMPANY_NAME,
                    "production_orders": batch_data
                }

                response = self.session.post(
                    API_BASE_URL + API_OPRO_ENDPOINT,
                    json=payload,
                    headers={
                        'Content-Type': 'application/json',
                        'X-Company-Token': COMPANY_TOKEN
                    },
                    timeout=API_TIMEOUT
                )

                logger.info(f"API Response Status: {response.status_code}")

                try:
                    response_content = response.json()
                    logger.debug(f"API Response Content: {json.dumps(response_content, indent=2)}")
                except:
                    logger.debug(f"API Response Text: {response.text}")
                    response_content = {}

                if response.status_code == 200:
                    try:
                        result = response_content
                        success_count = result.get('success_count', 0)
                        total_count = result.get('total_count', len(batch_data))
                        logger.info(f"API processed batch: {success_count}/{total_count} records successful")

                        existing_opros = []
                        for i, res in enumerate(result.get('results', [])):
                            if res.get('status') == 'error':
                                errors = res.get('errors', [])
                                logger.warning(f"Record {i} failed: {errors}")
                                error_str = str(errors).lower()
                                if "ya está en uso" in error_str or "already in use" in error_str:
                                    if i < len(batch_data):
                                        record = batch_data[i]
                                        opro = record.get('no_opro')
                                        if opro:
                                            existing_opros.append(opro)

                        return {
                            "success": True,
                            "data": result,
                            "existing_opros": existing_opros
                        }
                    except Exception as e:
                        logger.info(f"Batch sent successfully but error parsing response: {e}")
                        return {"success": True, "data": {}, "existing_opros": []}
                else:
                    logger.warning(f"API error {response.status_code}: {response.text}")
                    if attempt < MAX_RETRIES - 1:
                        time.sleep(2 ** attempt)

            except Exception as e:
                logger.error(f"Error sending batch (attempt {attempt + 1}): {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(2 ** attempt)

        return {"success": False, "error": "Failed after retries", "existing_opros": []}

    def process_production_orders(self) -> bool:
        """Process production orders from opro.dbf and oprod.dbf"""
        try:
            logger.info("=" * 60)
            logger.info("PROCESSING ZAVALA PRODUCTION ORDERS")
            logger.info("=" * 60)

            opro_exists = os.path.exists(OPRO_DBF_PATH)
            oprod_exists = os.path.exists(OPROD_DBF_PATH)

            if not opro_exists:
                logger.error(f"File not found: {OPRO_DBF_PATH}")
                return False

            opro_changed = self.first_run or self.has_file_changed(OPRO_DBF_PATH)
            oprod_changed = self.first_run or (oprod_exists and self.has_file_changed(OPROD_DBF_PATH))

            if not opro_changed and not oprod_changed:
                logger.info("No changes detected in OPRO DBF files")
                return True

            if self.first_run:
                logger.info("First run detected - will process all records")

            # Load DBF files
            logger.info(f"Opening DBF file: {OPRO_DBF_PATH}")
            opro_dbf = DBF(OPRO_DBF_PATH, ignore_missing_memofile=True)
            opro_records = list(opro_dbf)
            logger.info(f"Loaded {len(opro_records)} records from opro.dbf")

            oprod_records = []
            if oprod_exists:
                logger.info(f"Opening DBF file: {OPROD_DBF_PATH}")
                oprod_dbf = DBF(OPROD_DBF_PATH, ignore_missing_memofile=True)
                oprod_records = list(oprod_dbf)
                logger.info(f"Loaded {len(oprod_records)} records from oprod.dbf")

            all_records = self.merge_opro_oprod(opro_records, oprod_records)

            processed_count = 0
            new_records = []
            current_last_opro = self.opro_state.get('last_processed_opro', 0)
            logger.info(f"Starting process with known last NO_OPRO: {current_last_opro}")

            for record in all_records:
                no_opro = self.clean_value(record.get('NO_OPRO', ''))
                if not no_opro:
                    continue

                try:
                    current_opro_val = int(no_opro)
                    if current_opro_val > current_last_opro:
                        mapped_record = self.map_opro_record_to_api(record)
                        if mapped_record:
                            new_records.append(mapped_record)
                            processed_count += 1
                except ValueError:
                    continue

            logger.info(f"Found {processed_count} new records based on NO_OPRO sequence")

            new_records.sort(key=lambda x: int(self.clean_value(x.get('no_opro', '0'))) if self.clean_value(x.get('no_opro', '0')).isdigit() else 0)

            if not new_records:
                logger.info("No new production orders to send based on NO_OPRO sequence")
                self.save_opro_state()
                return True

            successful_sends = 0
            total_records = len(new_records)
            dynamic_last_opro = current_last_opro

            for i in range(0, len(new_records), BATCH_SIZE):
                batch = new_records[i:i + BATCH_SIZE]
                batch_num = i // BATCH_SIZE + 1

                try:
                    last_record_in_batch_opro = int(batch[-1]['no_opro'])
                    first_record_in_batch_opro = int(batch[0]['no_opro'])

                    if last_record_in_batch_opro <= dynamic_last_opro:
                        logger.info(f"Skipping batch {batch_num} (OPROs {first_record_in_batch_opro}-{last_record_in_batch_opro}) - already processed")
                        continue

                    if first_record_in_batch_opro <= dynamic_last_opro:
                        logger.info(f"Filtering batch {batch_num} - some records already processed")
                        batch = [r for r in batch if int(r['no_opro']) > dynamic_last_opro]
                        if not batch:
                            continue
                except (ValueError, IndexError):
                    pass

                logger.info(f"Processing batch {batch_num} ({len(batch)} records, OPROs {batch[0].get('no_opro')} - {batch[-1].get('no_opro')})")

                batch_result = self.send_opro_batch_to_api(batch)

                if batch_result.get("success"):
                    result_data = batch_result.get("data", {})
                    success_count = result_data.get('success_count', len(batch))
                    successful_sends += success_count
                    logger.info(f"Batch {batch_num} sent: {success_count} records successful")

                    existing_opros = batch_result.get("existing_opros", [])
                    if existing_opros:
                        logger.info(f"Detected {len(existing_opros)} existing records in this batch.")
                        try:
                            existing_ints = [int(o) for o in existing_opros if str(o).isdigit()]
                            if existing_ints:
                                max_existing = max(existing_ints)
                                if max_existing > dynamic_last_opro:
                                    logger.info(f"Fast-forwarding state: {dynamic_last_opro} -> {max_existing}")
                                    dynamic_last_opro = max_existing

                                    if max_existing > self.opro_state.get('last_processed_opro', 0):
                                        self.opro_state['last_processed_opro'] = max_existing
                                        self.save_opro_state()
                        except ValueError:
                            pass
                else:
                    logger.error(f"Batch {batch_num} failed: {batch_result.get('error')}")

            logger.info(f"Total production orders sent: {successful_sends}/{total_records}")

            if new_records:
                max_no_opro = max([int(r['no_opro']) for r in new_records if str(r['no_opro']).isdigit()], default=0)
                if max_no_opro > self.opro_state.get('last_processed_opro', 0):
                    self.opro_state['last_processed_opro'] = max_no_opro
                    self.save_opro_state()
                    logger.info(f"Updated last_processed_opro to {max_no_opro}")

            return True

        except Exception as e:
            logger.error(f"Error processing production orders: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False

    # ============================================================================
    # INVENTORY CODES METHODS
    # ============================================================================

    def map_inventory_record_to_api(self, record: Dict) -> Optional[Dict]:
        """Map DBF record to API format for inventory codes"""
        try:
            cleaned = {k: self.clean_value(v) for k, v in record.items()}

            # remd.dbf uses NO_REM instead of NO_ORDP
            no_ordp = cleaned.get('NO_REM', cleaned.get('NO_ORDP', ''))
            cve_prod = cleaned.get('CVE_PROD', '')
            cve_copr = cleaned.get('CVE_COPR', cleaned.get('CVE_PROD', ''))
            can_copr = cleaned.get('CAN_PROD', cleaned.get('CANT_PROD', cleaned.get('CANT_SURT', '0')))
            lote = cleaned.get('LOTE', cleaned.get('REF_LOTE', ''))
            fech_cto = cleaned.get('FECH_ORDP', cleaned.get('FECH_REM', ''))
            tip_copr = 1  # Default to active

            if not no_ordp:
                logger.warning("Skipping record: NO_REM/NO_ORDP is empty")
                return None

            if not cve_prod:
                logger.warning(f"Record with NO_REM/NO_ORDP {no_ordp} has empty CVE_PROD")
                return None

            parsed_date = None
            if fech_cto:
                try:
                    if 'T' in str(fech_cto):
                        parsed_date = fech_cto.split('T')[0]
                    else:
                        parsed_date = fech_cto
                except Exception:
                    parsed_date = datetime.now().strftime('%Y-%m-%d')
            else:
                parsed_date = datetime.now().strftime('%Y-%m-%d')

            try:
                quantity = float(can_copr) if can_copr else 0
                if quantity <= 0:
                    quantity = 1
            except ValueError:
                quantity = 1

            mapped = {
                "no_ordp": no_ordp,
                "cve_prod": cve_prod,
                "cve_copr": cve_copr,
                "can_copr": quantity,
                "lote": lote,
                "fech_cto": parsed_date,
                "tip_copr": tip_copr
            }

            mapped = {k: v for k, v in mapped.items() if v not in [None, '', 0] or k in ['tip_copr', 'can_copr']}

            logger.debug(f"Mapped inventory record - NO_ORDP: {mapped.get('no_ordp')}, "
                        f"Product: {mapped.get('cve_prod')}, "
                        f"Quantity: {mapped.get('can_copr')}")

            return mapped

        except Exception as e:
            logger.error(f"Error mapping inventory record: {e}")
            return None

    def send_inventory_batch_to_api(self, batch_data: List[Dict]) -> Dict:
        """Send a batch of inventory codes to the API endpoint"""
        for attempt in range(MAX_RETRIES):
            try:
                logger.info(f"Sending batch of {len(batch_data)} inventory codes to API")

                payload = {
                    "company_name": COMPANY_NAME,
                    "inventory_codes": batch_data
                }

                response = self.session.post(
                    API_BASE_URL + API_INVENTORY_ENDPOINT,
                    json=payload,
                    headers={
                        'Content-Type': 'application/json',
                        'X-Company-Token': COMPANY_TOKEN
                    },
                    timeout=API_TIMEOUT
                )

                logger.info(f"API Response Status: {response.status_code}")

                try:
                    response_content = response.json()
                    logger.debug(f"API Response Content: {json.dumps(response_content, indent=2)}")
                except:
                    logger.debug(f"API Response Text: {response.text}")
                    response_content = {}

                if response.status_code == 200:
                    try:
                        result = response_content
                        success_count = result.get('success_count', 0)
                        total_count = result.get('total_count', len(batch_data))
                        logger.info(f"API processed batch: {success_count}/{total_count} records successful")

                        return {
                            "success": True,
                            "data": result
                        }
                    except Exception as e:
                        logger.info(f"Batch sent successfully but error parsing response: {e}")
                        return {"success": True, "data": {}}
                else:
                    logger.warning(f"API error {response.status_code}: {response.text}")
                    if attempt < MAX_RETRIES - 1:
                        time.sleep(2 ** attempt)

            except Exception as e:
                logger.error(f"Error sending batch (attempt {attempt + 1}): {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(2 ** attempt)

        return {"success": False, "error": "Failed after retries"}

    def process_inventory_codes(self) -> bool:
        """Process inventory codes from remd.dbf"""
        try:
            logger.info("=" * 60)
            logger.info("PROCESSING ZAVALA INVENTORY CODES")
            logger.info("=" * 60)

            if not os.path.exists(REMD_DBF_PATH):
                logger.error(f"File not found: {REMD_DBF_PATH}")
                return False

            if not self.first_run and not self.has_file_changed(REMD_DBF_PATH):
                logger.info("No changes detected in REMD DBF file")
                return True

            if self.first_run:
                logger.info("First run detected - will process all records")

            logger.info(f"Opening DBF file: {REMD_DBF_PATH}")
            dbf = DBF(REMD_DBF_PATH, ignore_missing_memofile=True)

            # Log available fields for debugging
            logger.info(f"DBF fields: {dbf.field_names}")

            all_records = []
            processed_count = 0
            skipped_count = 0

            for record in dbf:
                record_dict = dict(record)
                mapped_record = self.map_inventory_record_to_api(record_dict)
                if mapped_record:
                    all_records.append(mapped_record)
                    processed_count += 1
                else:
                    skipped_count += 1

                    if processed_count % 100 == 0:
                        logger.info(f"Processed {processed_count} records so far...")

            logger.info(f"Prepared {len(all_records)} valid inventory records for sending (skipped {skipped_count})")

            all_records.sort(key=lambda x: str(x.get('no_ordp', '0')))

            if not all_records:
                logger.info("No valid inventory records to send")
                self.save_inventory_state()
                return True

            successful_sends = 0
            total_records = len(all_records)

            for i in range(0, len(all_records), BATCH_SIZE):
                batch = all_records[i:i + BATCH_SIZE]
                batch_num = i // BATCH_SIZE + 1

                logger.info(f"Processing inventory batch {batch_num} ({len(batch)} records)")

                batch_result = self.send_inventory_batch_to_api(batch)

                if batch_result.get("success"):
                    result_data = batch_result.get("data", {})
                    success_count = result_data.get('success_count', len(batch))
                    successful_sends += success_count
                    logger.info(f"Inventory batch {batch_num} sent: {success_count} records successful")
                else:
                    logger.error(f"Inventory batch {batch_num} failed: {batch_result.get('error')}")

            logger.info(f"Total inventory codes sent: {successful_sends}/{total_records}")

            if all_records:
                # Use NO_REM for state tracking (remd.dbf uses NO_REM)
                max_no_rem = max([int(r['no_ordp']) for r in all_records if str(r['no_ordp']).isdigit()], default=0)
                if max_no_rem > self.inventory_state.get('last_processed_no_ordp', 0):
                    self.inventory_state['last_processed_no_ordp'] = max_no_rem
                    self.save_inventory_state()
                    logger.info(f"Updated last_processed_no_ordp to {max_no_rem}")

            self.save_last_modified_state()
            self.first_run = False

            return True

        except Exception as e:
            logger.error(f"Error processing inventory codes: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False


def main():
    logger.info("=" * 60)
    logger.info("ZAVALA DBF UPLOADER - Starting")
    logger.info(f"Company: {COMPANY_NAME}")
    logger.info(f"Token: {COMPANY_TOKEN[:8]}...")
    logger.info("=" * 60)

    uploader = RzavalaDBFUploader()
    
    success_opro = uploader.process_production_orders()
    success_inventory = uploader.process_inventory_codes()

    if success_opro and success_inventory:
        logger.info("=" * 60)
        logger.info("ZAVALA DBF UPLOADER completed successfully")
        logger.info("=" * 60)
        sys.exit(0)
    else:
        logger.error("=" * 60)
        logger.error("ZAVALA DBF UPLOADER completed with errors")
        logger.error("=" * 60)
        sys.exit(1)


if __name__ == "__main__":
    main()
