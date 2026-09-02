export const normaliseKey = (value) => value.replace(/[^a-zA-Z0-9]/g, '').toLowerCase()

export const toApiField = (value) => (/^[A-Z]+$/.test(value) ? value.toLowerCase() : `${value.charAt(0).toLowerCase()}${value.slice(1)}`)

export const getRecordValue = (record, field) => {
  const key = Object.keys(record).find((entry) => normaliseKey(entry) === normaliseKey(field))
  return key ? record[key] : undefined
}

export const getOptionId = (record, entity) => getRecordValue(record, `${entity}ID`) ?? getRecordValue(record, 'id')
