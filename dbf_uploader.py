import requests
import time
import logging
from datetime import datetime
from dbfread import DBF
import os
import json
import hashlib
import sys
from typing import Dict, List, Optional, Any

# Configure logging
# Use a relative path for the log file to avoid permission issues
log_filename = 'corrected_schema_uploader.log'
# Ensure we're using the correct path separator for the current platform
log_filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), log_filename) if os.path.dirname(os.path.abspath(__file__)) else log_filename
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filepath, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('CorrectedSchemaUploader')
logger = logging.getLogger('CorrectedSchemaUploader')

# API configuration
API_BASE_URL = "https://wmsys.fly.dev"  # Production URL
# API_BASE_URL = "http://localhost:3000"  # Local development URL
API_ENDPOINT = "/api/production_orders/batch"
API_LAST_OPRO_ENDPOINT = "/api/production_orders/last_no_opro"
API_TIMEOUT = 90
MAX_RETRIES = 3

# Configuration
BATCH_SIZE = 25
# Configuration for file paths
BATCH_SIZE = 25

# For PyInstaller compatibility, we need to handle the _MEIPASS path
if getattr(sys, 'frozen', False):
    # Running as compiled executable
    application_path = sys._MEIPASS
    # For Windows executable, look for opro.dbf in the AlphaERP directory
    DBF_PATH = r"C:\ALPHAERP\Empresas\FLEXIEMP\opro.dbf"
else:
    # Running as script
    application_path = os.path.dirname(os.path.abspath(__file__))
    DBF_PATH = os.path.join(application_path, 'opro.dbf')

# Use a single state file for all environments
STATE_FILE = os.path.join(application_path, "dbf_state_corrected.json")
LAST_MODIFIED_FILE = os.path.join(application_path, "last_modified_state.json")

class CorrectedSchemaUploader:
    def __init__(self):
        self.session = requests.Session()
        self.state = self.load_state()
        self.last_modified_state = self.load_last_modified_state()
        # Check if this is the first run
        self.first_run = not os.path.exists(STATE_FILE) and not os.path.exists(LAST_MODIFIED_FILE)
        # Get last processed NO_OPRO from API (source of truth)
        self.sync_last_opro_from_api()
    
    def get_last_opro_from_api(self) -> int:
        """Get the last NO_OPRO from wmsys API"""
        try:
            logger.info("Fetching last NO_OPRO from API...")
            response = self.session.get(
                API_BASE_URL + API_LAST_OPRO_ENDPOINT,
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
        local_last_opro = self.state.get('last_processed_opro', 0)
        
        # Use the higher value between API and local state
        if api_last_opro > local_last_opro:
            logger.info(f"Syncing from API: {local_last_opro} -> {api_last_opro}")
            self.state['last_processed_opro'] = api_last_opro
            self.save_state()
        elif local_last_opro > api_last_opro:
            logger.info(f"Local state is ahead: {local_last_opro} > API: {api_last_opro}")
        
    def load_state(self) -> Dict:
        """Load the last processed state from file"""
        try:
            if os.path.exists(STATE_FILE):
                with open(STATE_FILE, 'r', encoding='utf-8') as f:
                    state = json.load(f)
                    if 'last_processed_opro' not in state:
                        state['last_processed_opro'] = 0
                    return state
        except Exception as e:
            logger.warning(f"Could not load state file: {e}")
        return {'last_processed_opro': 0}

    def save_state(self) -> bool:
        """Save the current state to file"""
        try:
            with open(STATE_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.state, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            logger.error(f"Error saving state: {e}")
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

    

    def is_new_record(self, no_opro: str) -> bool:
        """Check if this is a new record based on NO_OPRO sequence"""
        try:
            current_opro = int(no_opro)
            last_processed = self.state.get('last_processed_opro', 0)
            return current_opro > last_processed
        except ValueError:
            logger.warning(f"Invalid NO_OPRO value: {no_opro}")
            return False

    def clean_value(self, value: Any) -> str:
        """Clean and convert value to appropriate type"""
        if value is None or str(value).lower() in ['nan', 'none', '']:
            return ''
        # Handle date objects by converting them to strings
        if hasattr(value, 'strftime'):  # This will catch date, datetime, etc.
            return value.isoformat()
        return str(value).strip()

    def extract_quantity(self, record: Dict) -> int:
        """Extract meaningful quantity from various fields"""
        try:
            # Try different quantity fields in order of preference
            ren_opro = self.clean_value(record.get('REN_OPRO', '0'))
            carga_opro = self.clean_value(record.get('CARGA_OPRO', '0'))
            cant_liq = self.clean_value(record.get('CANT_LIQ', '0'))
            
            # Use the first valid non-zero value
            for value in [ren_opro, carga_opro, cant_liq]:
                if value and value.lower() not in ['nan', 'none', '', '0']:
                    try:
                        qty = float(value)
                        if qty > 0:
                            return max(1, int(qty))
                    except:
                        continue
                        
            # Default quantity if nothing found
            return 1000
        except:
            return 1000

    def extract_year(self, record: Dict) -> str:
        """Extract year from date field"""
        try:
            # Try different date fields
            fec_opro = self.clean_value(record.get('FEC_OPRO', ''))
            ano = self.clean_value(record.get('ANO', ''))
            
            # Try FEC_OPRO first
            if fec_opro:
                # Handle different date formats
                if '-' in fec_opro:
                    return fec_opro.split('-')[0]  # YYYY-MM-DD format
                elif '/' in fec_opro:
                    parts = fec_opro.split('/')
                    if len(parts) == 3:
                        # Assuming MM/DD/YYYY or DD/MM/YYYY, take the year part
                        return parts[2] if len(parts[2]) == 4 else ''
                elif len(fec_opro) >= 4:
                    # Direct year format
                    if fec_opro[:4].isdigit():
                        return fec_opro[:4]
            
            # Try ANO field
            if ano and ano.isdigit():
                return ano
                
            # Default to current year
            return str(datetime.now().year)
        except:
            return str(datetime.now().year)

    def map_record_to_api(self, record: Dict) -> Optional[Dict]:
        """Map DBF record to API format with CORRECT field mapping"""
        try:
            # Clean all values
            cleaned = {k: self.clean_value(v) for k, v in record.items()}
            
            # Extract year
            year = self.extract_year(cleaned)
            
            # Extract quantity
            quantity = self.extract_quantity(cleaned)
            
            # Get product key - this is the main identifier
            product_key = cleaned.get('CVE_PROP', '')
            
            # Validate required fields
            no_opro = cleaned.get('NO_OPRO', '')
            if not no_opro:
                logger.warning("Skipping record: NO_OPRO is empty")
                return None
                
            # Validate product key
            if not product_key:
                logger.warning(f"Record with NO_OPRO {no_opro} has empty CVE_PROP")
                # Still process it, but log the issue
                
            # CORRECT mapping based on your requirements:
            # Only include fields that are permitted by the API controller
            mapped = {
                # product_key is the external product identifier
                "product_key": product_key,
                
                # quantity from liquidated quantity
                "quantity_requested": quantity,
                
                # warehouse_id (use a valid warehouse ID)
                # "warehouse_id": "45c4bbc8-2950-434c-b710-2ae0e080bfd1",  # local
                "warehouse_id": "1ac67bd3-d5b1-4bbb-9f33-31d4a71af536",  # Warehouse for Flexiempaques
                
                # priority based on status
                "priority": "medium",  # Default, can be adjusted
                
                # NO_OPRO (numero de orden de produccion)
                "no_opro": no_opro,
                
                # NOTES should ONLY contain OBSERVA data
                "notes": cleaned.get('OBSERVA', ''),
                
                # LOTE (lote del producto)
                "lote_referencia": cleaned.get('LOTE', ''),
                
                # Year field
                "ano": year,  # Using 'ano' instead of 'year' to match model field
                
                # Other fields that are permitted by the API
                "stat_opro": cleaned.get('STAT_OPRO', ''),
                # Note: We're not including 'referencia' as it's not a valid column in the model
                # Note: We're not including 'status' as it should be set by the controller to a default value
            }
            
            # Remove empty fields to keep payload clean, but keep 'notes' field even if empty
            mapped = {k: v for k, v in mapped.items() if v not in [None, 0] or k == 'notes'}
            
            # Log mapping for verification
            logger.debug(f"Mapped record - NO_OPRO: {mapped.get('no_opro')}, "
                        f"Product: {mapped.get('product_key')}, "
                        f"Quantity: {mapped.get('quantity_requested')}, "
                        f"Year: {mapped.get('ano')}, "
                        f"Notes: '{mapped.get('notes', '')}'")
            
            # Log the final mapped dict for debugging
            logger.debug(f"Final mapped dict: {mapped}")
            
            return mapped
            
        except Exception as e:
            logger.error(f"Error mapping record: {e}")
            return None

    def send_batch_to_api(self, batch_data: List[Dict]) -> Dict:
        """Send a batch of records to the API endpoint"""
        for attempt in range(MAX_RETRIES):
            try:
                logger.info(f"Sending batch of {len(batch_data)} records to API")
                
                # Log the first record for debugging
                if batch_data:
                    logger.debug(f"First record sample: {batch_data[0]}")
                
                payload = {
                    "company_name": "Flexiempaques",
                    "production_orders": batch_data
                }
                
                logger.debug(f"Payload: {json.dumps(payload, indent=2, ensure_ascii=False, default=str)}")
                
                # Log specifically the notes values in the payload
                for i, order in enumerate(payload.get('production_orders', [])):
                    if 'notes' in order:
                        logger.debug(f"Order {i} notes: '{order['notes']}'")
                    if 'status' in order:
                        logger.debug(f"Order {i} status: '{order['status']}'")
                
                # Remove any 'status' fields that are empty before sending
                for order in payload.get('production_orders', []):
                    if 'status' in order and not order['status']:
                        del order['status']
                        logger.debug(f"Removed empty status field from order {order.get('no_opro', 'unknown')}")
                
                response = self.session.post(
                    API_BASE_URL + API_ENDPOINT,
                    json=payload,
                    headers={'Content-Type': 'application/json'},
                    timeout=API_TIMEOUT
                )
                
                logger.info(f"API Response Status: {response.status_code}")
                
                # Log response content for debugging
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
                        
                        # Log individual results and check for "already in use" errors
                        for i, res in enumerate(result.get('results', [])):
                            if res.get('status') == 'error':
                                errors = res.get('errors', [])
                                logger.warning(f"Record {i} failed: {errors}")
                                
                                # Check for "already in use" error
                                # Error format might varies, checking string presence
                                error_str = str(errors).lower()
                                if "ya está en uso" in error_str or "already in use" in error_str:
                                    # Try to get the NO_OPRO from the batch data at this index
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

    def process_dbf_file(self) -> bool:
        """Process DBF file with CORRECT schema mapping"""
        try:
            logger.info("=" * 60)
            logger.info("PROCESSING DBF WITH CORRECT SCHEMA MAPPING")
            logger.info("=" * 60)
            
            # Check if file exists
            if not os.path.exists(DBF_PATH):
                logger.error(f"File not found: {DBF_PATH}")
                return False
                
            # Check if DBF file has been modified
            if not self.first_run and not self.has_file_changed(DBF_PATH):
                logger.info("No changes detected in DBF file")
                # Also check for FPT file if it exists
                fpt_path = DBF_PATH.replace('.dbf', '.fpt')
                if os.path.exists(fpt_path) and self.has_file_changed(fpt_path):
                    logger.info("Changes detected in FPT file")
                else:
                    # Save state to persist last modified times
                    self.save_last_modified_state()
                    return True
            
            if self.first_run:
                logger.info("First run detected - will process all records")
                
            # Open DBF file with memo support
            logger.info(f"Opening DBF file: {DBF_PATH}")
            dbf = DBF(DBF_PATH, ignore_missing_memofile=False)
            
            # Process records based on NO_OPRO sequence
            all_records = []
            processed_count = 0
            new_records_count = 0
            
            # Get the initial last processed OPRO
            current_last_opro = self.state.get('last_processed_opro', 0)
            logger.info(f"Starting process with known last NO_OPRO: {current_last_opro}")
            
            for record in dbf:
                record_dict = dict(record)
                no_opro = self.clean_value(record_dict.get('NO_OPRO', ''))
                
                # Skip records without NO_OPRO
                if not no_opro:
                    continue
                
                # Use NO_OPRO sequence to determine which records to process
                # We check directly against the known state
                try:
                    current_opro_val = int(no_opro)
                    if current_opro_val > current_last_opro:
                        new_records_count += 1
                        mapped_record = self.map_record_to_api(record_dict)
                        if mapped_record:
                            all_records.append(mapped_record)
                            processed_count += 1
                            
                            # Log progress every 100 records
                            if processed_count % 100 == 0:
                                logger.info(f"Processed {processed_count} records so far...")
                except ValueError:
                    continue
            
            logger.info(f"Found {new_records_count} new records based on NO_OPRO sequence, prepared {len(all_records)} valid records for sending")
            
            # Sort records by NO_OPRO to maintain proper sequence
            all_records.sort(key=lambda x: int(self.clean_value(x.get('no_opro', '0'))) if self.clean_value(x.get('no_opro', '0')).isdigit() else 0)
            
            # Debug information
            logger.debug(f"New records based on NO_OPRO: {new_records_count}")
            logger.debug(f"Records to send: {len(all_records)}")
            logger.debug(f"First run: {self.first_run}")
            
            if not all_records:
                logger.info("No new records to send based on NO_OPRO sequence")
                # Save state to persist last modified times
                self.save_state()
                self.save_last_modified_state()
                # Reset first_run flag after first execution
                self.first_run = False
                return True
            
            # Send in batches
            successful_sends = 0
            total_records = len(all_records)
            
            # Track dynamic last processed OPRO during batch sending
            # This allows us to skip batches if we detect they are already in DB
            dynamic_last_opro = current_last_opro
            
            for i in range(0, len(all_records), BATCH_SIZE):
                batch = all_records[i:i + BATCH_SIZE]
                
                # Skip this batch if all records in it are already covered by dynamic_last_opro
                # We check the LAST record in the batch (since they are sorted)
                try:
                    last_record_in_batch_opro = int(batch[-1]['no_opro'])
                    first_record_in_batch_opro = int(batch[0]['no_opro'])
                    
                    if last_record_in_batch_opro <= dynamic_last_opro:
                        logger.info(f"Skipping batch {i//BATCH_SIZE + 1} (OPROs {first_record_in_batch_opro}-{last_record_in_batch_opro}) - already processed/exists")
                        continue
                        
                    # If partially processed (rare due to batching), filter out already processed ones
                    if first_record_in_batch_opro <= dynamic_last_opro:
                        logger.info(f"Filtering batch {i//BATCH_SIZE + 1} - some records already processed")
                        batch = [r for r in batch if int(r['no_opro']) > dynamic_last_opro]
                        if not batch:
                            continue
                except (ValueError, IndexError):
                    pass
                
                logger.info(f"Processing batch {i//BATCH_SIZE + 1} ({len(batch)} records, OPROs {batch[0].get('no_opro')} - {batch[-1].get('no_opro')})")
                
                batch_result = self.send_batch_to_api(batch)
                
                if batch_result.get("success"):
                    result_data = batch_result.get("data", {})
                    success_count = result_data.get('success_count', len(batch))
                    successful_sends += success_count
                    logger.info(f"Batch {i//BATCH_SIZE + 1} sent: {success_count} records successful")
                    
                    # Check for "existing_opros" to fast-forward state
                    existing_opros = batch_result.get("existing_opros", [])
                    if existing_opros:
                        logger.info(f"Detected {len(existing_opros)} existing records in this batch.")
                        try:
                            # Convert to ints to find max
                            existing_ints = [int(o) for o in existing_opros if str(o).isdigit()]
                            if existing_ints:
                                max_existing = max(existing_ints)
                                if max_existing > dynamic_last_opro:
                                    logger.info(f"Fast-forwarding state: {dynamic_last_opro} -> {max_existing}")
                                    dynamic_last_opro = max_existing
                                    
                                    # Update persistent state immediately to avoid reprocessing on restart
                                    if max_existing > self.state.get('last_processed_opro', 0):
                                        self.state['last_processed_opro'] = max_existing
                                        self.save_state()
                        except ValueError:
                            pass
                else:
                    logger.error(f"Batch {i//BATCH_SIZE + 1} failed: {batch_result.get('error')}")
            
            logger.info(f"Total records sent: {successful_sends}/{total_records}")
            
            # Update and save state to track the highest NO_OPRO processed
            # We use dynamic_last_opro which might have been updated from "existing" errors
            # Or from successfully processed records
            
            # Also check the actually processed records to ensure we cover successful sends
            if all_records:
                valid_opros = []
                for record in all_records:
                    no_opro = self.clean_value(record.get('no_opro', '0'))
                    if no_opro.isdigit():
                        valid_opros.append(int(no_opro))
                
                if valid_opros:
                    max_in_batch = max(valid_opros)
                    if max_in_batch > dynamic_last_opro:
                        dynamic_last_opro = max_in_batch
            
            # Final state update
            if dynamic_last_opro > self.state.get('last_processed_opro', 0):
                self.state['last_processed_opro'] = dynamic_last_opro
                logger.info(f"Updated last processed NO_OPRO to: {dynamic_last_opro}")
            
            # Save state to persist last modified times and NO_OPRO tracking
            self.save_state()
            self.save_last_modified_state()
            # Reset first_run flag after first execution
            self.first_run = False
            
            return True
            
        except Exception as e:
            logger.error(f"Error processing DBF file: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return False

def main():
    """Main function"""
    logger.info("Starting CORRECTED SCHEMA DBF Uploader")
    
    # Check if force send flag is set
    force_send = '--force-send' in sys.argv
    
    # Check if clear state flag is set
    if '--clear-state' in sys.argv:
        logger.info("Clearing state file...")
        if os.path.exists(STATE_FILE):
            os.remove(STATE_FILE)
            logger.info(f"State file {STATE_FILE} cleared")
        else:
            logger.info("State file not found")
        
        if os.path.exists(LAST_MODIFIED_FILE):
            os.remove(LAST_MODIFIED_FILE)
            logger.info(f"Last modified file {LAST_MODIFIED_FILE} cleared")
        else:
            logger.info("Last modified file not found")
    
    # Check if clear state for specific environment flag is set
    if '--clear-local-state' in sys.argv and not getattr(sys, 'frozen', False):
        logger.info("Clearing local state files...")
        local_state_files = [
            "dbf_state_corrected_unix.json",
            "dbf_state_corrected.json"
        ]
        for state_file in local_state_files:
            full_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), state_file)
            if os.path.exists(full_path):
                os.remove(full_path)
                logger.info(f"Local state file {state_file} cleared")
        
        local_modified_files = [
            "last_modified_state_unix.json",
            "last_modified_state.json"
        ]
        for mod_file in local_modified_files:
            full_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), mod_file)
            if os.path.exists(full_path):
                os.remove(full_path)
                logger.info(f"Local last modified file {mod_file} cleared")
    
    if '--clear-server-state' in sys.argv and getattr(sys, 'frozen', False):
        logger.info("Clearing server state files...")
        server_state_files = [
            "dbf_state_corrected_windows.json",
            "dbf_state_corrected.json"
        ]
        for state_file in server_state_files:
            full_path = os.path.join(sys._MEIPASS if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__)), state_file)
            if os.path.exists(full_path):
                os.remove(full_path)
                logger.info(f"Server state file {state_file} cleared")
        
        server_modified_files = [
            "last_modified_state_windows.json",
            "last_modified_state.json"
        ]
        for mod_file in server_modified_files:
            full_path = os.path.join(sys._MEIPASS if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__)), mod_file)
            if os.path.exists(full_path):
                os.remove(full_path)
                logger.info(f"Server last modified file {mod_file} cleared")
    
    uploader = CorrectedSchemaUploader()
    
    # Run in continuous mode
    while True:
        try:
            logger.info("Checking for DBF file updates...")
            if force_send:
                logger.info("Force send mode enabled - sending all records")
                # Temporarily reset NO_OPRO tracking to force sending all records
                uploader.state['last_processed_opro'] = 0  # Reset to process all records
            
            success = uploader.process_dbf_file()
            
            if success:
                logger.info("Upload cycle completed successfully!")
            else:
                logger.error("Upload cycle failed!")
                
            # Wait before next check (30 seconds)
            logger.info("Waiting 30 seconds before next check...")
            time.sleep(30)
            
        except KeyboardInterrupt:
            logger.info("Upload process interrupted by user")
            # Save state before exiting
            uploader.save_state()
            uploader.save_last_modified_state()
            break
        except Exception as e:
            logger.error(f"Error in upload cycle: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            # Wait before retrying after error
            time.sleep(30)

if __name__ == '__main__':
    main()